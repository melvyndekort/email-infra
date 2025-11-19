"""Tests for DMARC handler."""

import gzip
import os
from unittest.mock import Mock, patch
import pytest

from email_infra.handler import handler


def test_handler_with_empty_records():
    """Test handler with empty S3 records."""
    event = {"Records": []}
    context = Mock()

    result = handler(event, context)

    assert result["statusCode"] == 200
    assert "successfully" in result["body"]


@patch("email_infra.handler.requests.post")
@patch("email_infra.handler._get_grafana_token")
@patch("email_infra.handler.boto3.client")
@patch.dict(os.environ, {
    "GRAFANA_PUSH_URL": "https://test.grafana.net/api/v1/push",
    "GRAFANA_USER_ID": "test_user"
})
def test_handler_with_s3_record(mock_boto3, mock_get_token, mock_requests):
    """Test handler with S3 record."""
    # Mock S3 client
    mock_s3 = Mock()
    mock_boto3.return_value = mock_s3

    # Mock Grafana token
    mock_get_token.return_value = "test-token"

    # Mock requests response
    mock_requests.return_value.raise_for_status.return_value = None

    # Mock S3 response with simple XML
    xml_content = ('<feedback><report_metadata><org_name>test</org_name></report_metadata>'
                   '<record><row><source_ip>1.2.3.4</source_ip><count>1</count>'
                   '<policy_evaluated><dmarc>pass</dmarc><spf>pass</spf><dkim>pass</dkim>'
                   '</policy_evaluated></row></record></feedback>')
    xml_bytes = xml_content.encode()
    mock_s3.get_object.return_value = {
        "Body": Mock(read=lambda: xml_bytes)
    }

    event = {
        "Records": [{
            "s3": {
                "bucket": {"name": "test-bucket"},
                "object": {"key": "test-report.xml"}
            }
        }]
    }
    context = Mock()

    result = handler(event, context)

    assert result["statusCode"] == 200
    assert "successfully" in result["body"]

    # Verify Grafana calls
    assert mock_requests.call_count == 3  # email_count, spf_result, dkim_result
    mock_get_token.assert_called()

    # Verify protobuf format is used
    for call in mock_requests.call_args_list:
        _, kwargs = call
        assert 'data' in kwargs  # Binary data instead of json
        assert kwargs['headers']['Content-Type'] == 'application/x-protobuf'
        assert kwargs['headers']['Content-Encoding'] == 'snappy'


@patch("email_infra.handler.requests.post")
@patch("email_infra.handler._get_grafana_token")
@patch("email_infra.handler.boto3.client")
@patch.dict(os.environ, {
    "GRAFANA_PUSH_URL": "https://test.grafana.net/api/v1/push",
    "GRAFANA_USER_ID": "test_user"
})
def test_handler_with_gzipped_content(mock_boto3, mock_get_token, mock_requests):
    """Test handler with gzipped S3 content."""
    # Mock S3 client
    mock_s3 = Mock()
    mock_boto3.return_value = mock_s3

    # Mock Grafana token
    mock_get_token.return_value = "test-token"

    # Mock requests response
    mock_requests.return_value.raise_for_status.return_value = None

    # Create gzipped XML content
    xml_content = ('<feedback><report_metadata><org_name>test</org_name></report_metadata>'
                   '<record><row><source_ip>1.2.3.4</source_ip><count>1</count>'
                   '<policy_evaluated><dmarc>pass</dmarc><spf>pass</spf><dkim>pass</dkim>'
                   '</policy_evaluated></row></record></feedback>')
    gzipped_content = gzip.compress(xml_content.encode())

    mock_s3.get_object.return_value = {
        "Body": Mock(read=lambda: gzipped_content)
    }

    event = {
        "Records": [{
            "s3": {
                "bucket": {"name": "test-bucket"},
                "object": {"key": "test-report.xml.gz"}
            }
        }]
    }
    context = Mock()

    result = handler(event, context)

    assert result["statusCode"] == 200
    assert "successfully" in result["body"]

    # Verify Grafana calls
    assert mock_requests.call_count == 3


@patch("email_infra.handler.requests.post")
@patch("email_infra.handler._get_grafana_token")
@patch("email_infra.handler.boto3.client")
@patch.dict(os.environ, {
    "GRAFANA_PUSH_URL": "https://test.grafana.net/api/v1/push",
    "GRAFANA_USER_ID": "test_user"
})
def test_handler_with_missing_xml_elements(mock_boto3, mock_get_token, mock_requests):
    """Test handler with XML missing some elements."""
    # Mock S3 client
    mock_s3 = Mock()
    mock_boto3.return_value = mock_s3

    # Mock Grafana token
    mock_get_token.return_value = "test-token"

    # Mock requests response
    mock_requests.return_value.raise_for_status.return_value = None

    # Mock S3 response with minimal XML (missing some elements)
    mock_s3.get_object.return_value = {
        "Body": Mock(read=lambda: b'<feedback><record><row><count>5</count></row></record></feedback>')
    }

    event = {
        "Records": [{
            "s3": {
                "bucket": {"name": "test-bucket"},
                "object": {"key": "minimal-report.xml"}
            }
        }]
    }
    context = Mock()

    result = handler(event, context)

    assert result["statusCode"] == 200
    assert "successfully" in result["body"]

    # Verify Grafana calls with default values
    assert mock_requests.call_count == 3


@patch("email_infra.handler.boto3.client")
def test_handler_with_s3_error(mock_boto3):
    """Test handler with S3 error."""
    mock_s3 = Mock()
    mock_boto3.return_value = mock_s3
    mock_s3.get_object.side_effect = Exception("S3 error")

    event = {
        "Records": [{
            "s3": {
                "bucket": {"name": "test-bucket"},
                "object": {"key": "error-report.xml"}
            }
        }]
    }
    context = Mock()

    with pytest.raises(Exception, match="S3 error"):
        handler(event, context)
