import time

import py_zipkin.util
import requests


def main():
    now = int(time.time() * 1000 * 1000)
    trace_id = py_zipkin.util.generate_random_128bit_string()
    root_span_id = py_zipkin.util.generate_random_64bit_string()
    server_span_id = py_zipkin.util.generate_random_64bit_string()
    print(trace_id)

    trace = [
        {
            'traceId': trace_id,
            'name': 'GET /foo',
            'id': root_span_id,
            'kind': 'SERVER',
            'timestamp': now,
            'duration': 100 * 1000,
            'localEndpoint': {
                'serviceName': 'test_service',
                'ipv4': '127.0.0.1',
                'port': 80,
            },
        },
        {
            'traceId': trace_id,
            'name': 'MySQL select',
            'parentId': root_span_id,
            'id': py_zipkin.util.generate_random_64bit_string(),
            'kind': 'CLIENT',
            'timestamp': now + 1000,
            'duration': 10 * 1000,
            'localEndpoint': {
                'serviceName': 'test_service',
                'ipv4': '127.0.0.1',
                'port': 80,
            },
        },
        {
            'traceId': trace_id,
            'name': 'get /bar',
            'parentId': root_span_id,
            'id': server_span_id,
            'kind': 'CLIENT',
            'timestamp': now + 11 * 1000,
            'duration': 60 * 1000,
            'localEndpoint': {
                'serviceName': 'test_service',
                'ipv4': '127.0.0.1',
                'port': 80,
            },
        },
        {
            'traceId': trace_id,
            'name': 'get /bar',
            'parentId': root_span_id,
            'id': server_span_id,
            'kind': 'SERVER',
            'timestamp': now + 15 * 1000,
            'duration': 55 * 1000,
            'localEndpoint': {
                'serviceName': 'client_service',
                'ipv4': '127.0.0.2',
                'port': 80,
            },
        },
    ]

    r = requests.post('http://zipkin-uswest1a:9411/api/v2/spans', json=trace[0:2])
    assert r.status_code == 202
    r = requests.post('http://zipkin-uswest1b:9411/api/v2/spans', json=trace[2:4])
    assert r.status_code == 202


if __name__ == '__main__':
    main()
