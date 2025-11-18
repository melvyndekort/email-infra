"""DMARC report processing Lambda handler."""

import gzip
import json
import logging
import os
import time
import xml.etree.ElementTree as ET

import boto3
import requests

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def _extract_text_or_default(element, default='unknown'):
    """Extract text from XML element or return default."""
    return element.text if element is not None else default


def _get_grafana_token():
    """Get Grafana token from Parameter Store."""
    ssm = boto3.client('ssm')
    response = ssm.get_parameter(Name='/grafana/token', WithDecryption=True)
    return response['Parameter']['Value']


def _send_to_grafana(metric_name, value, labels=None):
    """Send metric to Grafana Cloud Prometheus."""
    grafana_url = os.environ['GRAFANA_PUSH_URL']
    grafana_token = _get_grafana_token()

    labels = labels or {}
    labels['__name__'] = metric_name

    # Prometheus remote write protobuf format
    timestamp_ms = int(time.time() * 1000)

    payload = {
        "timeseries": [{
            "labels": [{"name": k, "value": v} for k, v in labels.items()],
            "samples": [{"value": float(value), "timestamp": timestamp_ms}]
        }]
    }

    response = requests.post(
        grafana_url,
        json=payload,
        headers={
            "Authorization": f"Bearer {grafana_token}",
            "Content-Type": "application/json"
        },
        timeout=10
    )
    response.raise_for_status()


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

    dmarc_elem = policy_eval.find('.//dmarc') if policy_eval is not None else None
    dmarc_result = _extract_text_or_default(dmarc_elem)

    spf_elem = policy_eval.find('.//spf') if policy_eval is not None else None
    spf_result = _extract_text_or_default(spf_elem)

    dkim_elem = policy_eval.find('.//dkim') if policy_eval is not None else None
    dkim_result = _extract_text_or_default(dkim_elem)

    return dmarc_result, spf_result, dkim_result


def _send_metrics(org_name, source_ip, count, results):
    """Send DMARC metrics to Grafana Cloud."""
    dmarc_result, spf_result, dkim_result = results

    base_labels = {
        'organization': org_name,
        'source_ip': source_ip
    }

    # Email count metric
    _send_to_grafana('dmarc_email_count', count, {
        **base_labels,
        'dmarc_result': dmarc_result
    })

    # SPF result metric
    _send_to_grafana('dmarc_spf_result', count, {
        **base_labels,
        'result': spf_result
    })

    # DKIM result metric
    _send_to_grafana('dmarc_dkim_result', count, {
        **base_labels,
        'result': dkim_result
    })


def _process_dmarc_record(record_elem, org_name):
    """Process a single DMARC record and send metrics."""
    source_ip, count = _extract_record_data(record_elem)
    policy_results = _extract_policy_results(record_elem)

    _send_metrics(org_name, source_ip, count, policy_results)

    LOGGER.info("Sent metrics for %d emails from %s (DMARC: %s)",
               count, source_ip, policy_results[0])


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

    # Get and decompress content
    response = s3.get_object(Bucket=bucket, Key=key)
    content = _decompress_content(response['Body'].read())

    # Parse XML and extract metadata
    root = ET.fromstring(content)
    org_name, report_id = _extract_report_metadata(root)

    LOGGER.info("Processing report from %s, ID: %s", org_name, report_id)

    # Process each record
    for record_elem in root.findall('.//record'):
        _process_dmarc_record(record_elem, org_name)


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
