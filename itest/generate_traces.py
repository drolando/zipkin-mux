import time

import py_zipkin
import requests


def main():
    now = int(time.time() * 1000 * 1000)
    trace_id = py_zipkin.util.generate_random_128bit_string()
    root_span_id = py_zipkin.util.generate_random_64bit_string()

    trace = [
        {
            'traceId': trace_id,
            'name': 'GET /foo',
            'id': root_span_id,
            'kind': 'SERVER',
            'timestamp': now,
            'duration': 100 * 1000,
        },
        {
            'traceId': trace_id,
            'name': 'MySQL select',
            'parentId': root_span_id,
            'id': py_zipkin.util.generate_random_64bit_string(),
            'kind': 'SERVER',
            'timestamp': now,
            'duration': 100 * 1000,
        },
    ]

    requests.post('http://zipkin-uswest1a/spans', json=trace)


if __name__ == '__main__':
    main()
