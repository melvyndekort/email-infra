"""DMARC report processing Lambda handler."""

import gzip
import json
import logging
import os
import struct
import time
import xml.etree.ElementTree as ET
import zipfile
from email import message_from_bytes
from io import BytesIO

import boto3
import requests

try:
    import cramjam
    HAS_SNAPPY = True
except ImportError:
    HAS_SNAPPY = False

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def _extract_text_or_default(element, default='unknown'):
    """Extract text from XML element or return default."""
    return element.text if element is not None else default


def _encode_varint(value):
    """Encode integer as protobuf varint."""
    result = b''
    while value >= 0x80:
        result += bytes([value & 0x7F | 0x80])
        value >>= 7
    result += bytes([value & 0x7F])
    return result


def _encode_string(field_number, value):
    """Encode string field for protobuf."""
    encoded_value = value.encode('utf-8')
    return (_encode_varint(field_number << 3 | 2) +
            _encode_varint(len(encoded_value)) +
            encoded_value)


def _encode_double(field_number, value):
    """Encode double field for protobuf."""
    return (_encode_varint(field_number << 3 | 1) +
            struct.pack('<d', float(value)))


def _encode_int64(field_number, value):
    """Encode int64 field for protobuf."""
    return _encode_varint(field_number << 3) + _encode_varint(int(value))


def _create_label(name, value):
    """Create a protobuf label."""
    return (_encode_string(1, name) + _encode_string(2, value))


def _create_sample(value, timestamp_ms):
    """Create a protobuf sample."""
    return (_encode_double(1, value) + _encode_int64(2, timestamp_ms))


def _create_timeseries(metric_name, value, labels, timestamp_ms):
    """Create a protobuf timeseries."""
    # Add __name__ label
    all_labels = [_create_label('__name__', metric_name)]
    for k, v in labels.items():
        all_labels.append(_create_label(k, v))

    # Encode labels
    labels_data = b''
    for label in all_labels:
        labels_data += _encode_varint(1 << 3 | 2) + _encode_varint(len(label)) + label

    # Encode sample
    sample = _create_sample(value, timestamp_ms)
    samples_data = _encode_varint(2 << 3 | 2) + _encode_varint(len(sample)) + sample

    return labels_data + samples_data


def _create_write_request(timeseries_list):
    """Create a protobuf WriteRequest."""
    result = b''
    for ts in timeseries_list:
        result += _encode_varint(1 << 3 | 2) + _encode_varint(len(ts)) + ts
    return result


def _get_grafana_token():
    """Get Grafana token from Parameter Store."""
    ssm = boto3.client('ssm')
    response = ssm.get_parameter(Name='/grafana/token', WithDecryption=True)
    return response['Parameter']['Value']


def _send_metrics_batch(metrics_list):
    """Send multiple metrics to Grafana Cloud in a single request."""
    if not metrics_list:
        return

    grafana_url = os.environ['GRAFANA_PUSH_URL']
    grafana_token = _get_grafana_token()
    timestamp_ms = int(time.time() * 1000)

    # Create timeseries for all metrics
    timeseries_list = []
    for metric_name, value, labels in metrics_list:
        timeseries = _create_timeseries(metric_name, value, labels, timestamp_ms)
        timeseries_list.append(timeseries)

    # Create write request with all timeseries
    write_request = _create_write_request(timeseries_list)

    # Compress with snappy using cramjam (raw format for Prometheus)
    if HAS_SNAPPY:
        compressed_data = bytes(cramjam.snappy.compress_raw(write_request))
        content_encoding = "snappy"
    else:
        # Fallback to gzip if snappy not available
        compressed_data = gzip.compress(write_request)
        content_encoding = "gzip"
        LOGGER.warning("Using gzip compression instead of snappy")

    response = requests.post(
        grafana_url,
        data=compressed_data,
        auth=(os.environ['GRAFANA_USER_ID'], grafana_token),
        headers={
            "Content-Type": "application/x-protobuf",
            "Content-Encoding": content_encoding
        },
        timeout=10
    )

    if response.status_code != 200:
        LOGGER.error("Grafana error %d: %s", response.status_code, response.text)

    response.raise_for_status()
    LOGGER.info("Sent batch of %d metrics to Grafana", len(metrics_list))


def _extract_report_metadata(root):
    """Extract organization name and report ID from XML root."""
    org_name = _extract_text_or_default(root.find('.//org_name'))
    report_id = _extract_text_or_default(root.find('.//report_id'))
    return org_name, report_id


def _extract_record_data(record_elem):
    """Extract source IP and count from record element."""
    source_ip = _extract_text_or_default(record_elem.find('.//source_ip'))
    count_elem = record_elem.find('.//count')
    count = int(count_elem.text) if count_elem is not None else 0
    return source_ip, count


def _extract_policy_results(record_elem):
    """Extract DMARC, SPF, and DKIM results from record element."""
    policy_eval = record_elem.find('.//policy_evaluated')

    dmarc_elem = policy_eval.find('.//disposition') if policy_eval is not None else None
    dmarc_result = _extract_text_or_default(dmarc_elem)

    spf_elem = policy_eval.find('.//spf') if policy_eval is not None else None
    spf_result = _extract_text_or_default(spf_elem)

    dkim_elem = policy_eval.find('.//dkim') if policy_eval is not None else None
    dkim_result = _extract_text_or_default(dkim_elem)

    return dmarc_result, spf_result, dkim_result


def _collect_metrics(org_name, source_ip, count, results):
    """Collect DMARC metrics for batching."""
    dmarc_result, spf_result, dkim_result = results

    base_labels = {
        'organization': org_name,
        'source_ip': source_ip
    }

    return [
        ('dmarc_email_count', count, {**base_labels, 'dmarc_result': dmarc_result}),
        ('dmarc_spf_result', count, {**base_labels, 'result': spf_result}),
        ('dmarc_dkim_result', count, {**base_labels, 'result': dkim_result}),
    ]


def _process_dmarc_record(record_elem, org_name):
    """Process a single DMARC record and collect metrics."""
    source_ip, count = _extract_record_data(record_elem)
    policy_results = _extract_policy_results(record_elem)

    metrics = _collect_metrics(org_name, source_ip, count, policy_results)

    LOGGER.info("Collected metrics for %d emails from %s (DMARC: %s)",
               count, source_ip, policy_results[0])

    return metrics


def _extract_xml_from_email(content):
    """Extract XML content from email message attachments."""
    try:
        # Parse email message
        msg = message_from_bytes(content)

        # Look for attachments
        for part in msg.walk():
            if part.get_content_disposition() == 'attachment':
                payload = part.get_payload(decode=True)
                if payload:
                    # Check if it's a ZIP file
                    if part.get_content_type() == 'application/zip' or part.get_filename('').endswith('.zip'):
                        try:
                            with zipfile.ZipFile(BytesIO(payload)) as zip_file:
                                for file_name in zip_file.namelist():
                                    if file_name.endswith('.xml'):
                                        xml_content = zip_file.read(file_name)
                                        LOGGER.info("Found XML file in ZIP attachment: %s", file_name)
                                        return xml_content
                        except zipfile.BadZipFile:
                            LOGGER.info("Invalid ZIP file in attachment")
                            continue

                    # Try to decompress if gzipped
                    try:
                        payload = gzip.decompress(payload)
                        LOGGER.info("Decompressed gzipped attachment")
                    except Exception:  # pylint: disable=broad-except
                        LOGGER.info("Attachment not gzipped")

                    # Check if it's XML content
                    try:
                        ET.fromstring(payload)
                        LOGGER.info("Found XML attachment")
                        return payload
                    except ET.ParseError:
                        continue

        # If no attachment found, maybe the XML is in the email body
        if msg.is_multipart():
            for part in msg.walk():
                if part.get_content_type() == 'text/plain':
                    payload = part.get_payload(decode=True)
                    if payload:
                        try:
                            ET.fromstring(payload)
                            LOGGER.info("Found XML in email body")
                            return payload
                        except ET.ParseError:
                            continue
        else:
            # Single part message
            payload = msg.get_payload(decode=True)
            if payload:
                try:
                    ET.fromstring(payload)
                    LOGGER.info("Found XML in single-part email")
                    return payload
                except ET.ParseError:
                    pass

        raise ValueError("No valid XML content found in email")

    except Exception as exc:
        LOGGER.error("Failed to extract XML from email: %s", str(exc))
        raise


def _decompress_content(content):
    """Decompress content if it's gzipped."""
    try:
        decompressed = gzip.decompress(content)
        LOGGER.info("Decompressed gzipped content")
        return decompressed
    except Exception:  # pylint: disable=broad-except
        LOGGER.info("Content not gzipped")
        return content


def _process_s3_object(bucket, key, s3):
    """Process a single S3 object containing DMARC report."""
    LOGGER.info("Processing DMARC report: %s", key)

    # Get content from S3
    response = s3.get_object(Bucket=bucket, Key=key)
    raw_content = response['Body'].read()

    # Try to extract XML from email first, fallback to direct XML parsing
    try:
        content = _extract_xml_from_email(raw_content)
    except Exception:  # pylint: disable=broad-except
        LOGGER.info("Not an email message, trying direct XML parsing")
        content = _decompress_content(raw_content)

    # Parse XML and extract metadata
    root = ET.fromstring(content)
    org_name, report_id = _extract_report_metadata(root)

    LOGGER.info("Processing report from %s, ID: %s", org_name, report_id)

    # Collect metrics from all records
    all_metrics = []
    for record_elem in root.findall('.//record'):
        metrics = _process_dmarc_record(record_elem, org_name)
        all_metrics.extend(metrics)

    # Send all metrics in a single batch
    _send_metrics_batch(all_metrics)


def handler(event, _context):
    """Process DMARC reports from S3 events."""
    s3 = boto3.client('s3')

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        try:
            _process_s3_object(bucket, key, s3)
        except Exception as exc:
            LOGGER.error("Error processing %s: %s", key, str(exc))
            raise

    return {
        'statusCode': 200,
        'body': json.dumps('DMARC reports processed successfully')
    }
