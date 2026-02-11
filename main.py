import http.server
import socketserver
import json
import os
import csv
import urllib.parse

PORT = 8000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    # Ensure correct MIME types for Safari
    extensions_map = http.server.SimpleHTTPRequestHandler.extensions_map.copy()
    extensions_map.update({
        '.css': 'text/css',
        '.js': 'application/javascript',
    })

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_GET(self):
        # API to list CSV files
        if self.path == '/api/data':
            data_dir = os.path.join(DIRECTORY, 'data')
            files = [f for f in os.listdir(data_dir) if f.endswith('.csv')]
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(files).encode())
            return

        # API to get CSV content
        elif self.path.startswith('/api/data/'):
            filename = urllib.parse.unquote(self.path.split('/')[-1])
            filepath = os.path.join(DIRECTORY, 'data', filename)
            
            if os.path.exists(filepath):
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        reader = csv.DictReader(f)
                        rows = list(reader)
                        headers = reader.fieldnames if reader.fieldnames else []
                    
                    response = {
                        'headers': headers,
                        'rows': rows
                    }
                    
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps(response).encode())
                except Exception as e:
                    self.send_error(500, str(e))
            else:
                self.send_error(404, "File not found")
            return

        else:
            # Serve the app/index.html as the root
            if self.path == '/':
                self.path = '/app/index.html'
            # Default static file serving
            return super().do_GET()

    def do_POST(self):
        # API to add a row
        if '/add_row' in self.path:
            # path format: /api/data/<filename>/add_row
            parts = self.path.split('/')
            if len(parts) >= 4:
                filename = urllib.parse.unquote(parts[3])
                filepath = os.path.join(DIRECTORY, 'data', filename)

                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                try:
                    data = json.loads(post_data.decode('utf-8'))
                    row_data = data.get('row')

                    if not row_data:
                        self.send_error(400, "Missing 'row' field")
                        return

                    if os.path.exists(filepath):
                        # Read existing data to get headers
                        with open(filepath, 'r', encoding='utf-8') as f:
                            reader = csv.DictReader(f)
                            rows = list(reader)
                            headers = reader.fieldnames if reader.fieldnames else []

                        # Build new row dict
                        new_row = {}
                        for h in headers:
                            new_row[h] = row_data.get(h, '')

                        rows.append(new_row)

                        # Write back
                        with open(filepath, 'w', encoding='utf-8', newline='') as f:
                            writer = csv.DictWriter(f, fieldnames=headers)
                            writer.writeheader()
                            writer.writerows(rows)
                        
                        # Return updated data
                        response = {
                            'headers': headers,
                            'rows': rows
                        }

                        self.send_response(200)
                        self.send_header('Content-type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps(response).encode())
                    else:
                        self.send_error(404, "File not found")

                except Exception as e:
                    self.send_error(500, str(e))
            else:
                self.send_error(400, "Invalid URL format")
            return

        # API to update a row
        elif '/update_row' in self.path:
            parts = self.path.split('/')
            if len(parts) >= 4:
                filename = urllib.parse.unquote(parts[3])
                filepath = os.path.join(DIRECTORY, 'data', filename)

                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                try:
                    data = json.loads(post_data.decode('utf-8'))
                    row_index = data.get('row_index')
                    row_data = data.get('row')

                    if row_index is None or not row_data:
                        self.send_error(400, "Missing 'row_index' or 'row' field")
                        return

                    if os.path.exists(filepath):
                        with open(filepath, 'r', encoding='utf-8') as f:
                            reader = csv.DictReader(f)
                            rows = list(reader)
                            headers = reader.fieldnames if reader.fieldnames else []

                        if row_index < 0 or row_index >= len(rows):
                            self.send_error(400, "Invalid row_index")
                            return

                        for h in headers:
                            if h in row_data:
                                rows[row_index][h] = row_data[h]

                        with open(filepath, 'w', encoding='utf-8', newline='') as f:
                            writer = csv.DictWriter(f, fieldnames=headers)
                            writer.writeheader()
                            writer.writerows(rows)

                        response = {
                            'headers': headers,
                            'rows': rows
                        }

                        self.send_response(200)
                        self.send_header('Content-type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps(response).encode())
                    else:
                        self.send_error(404, "File not found")

                except Exception as e:
                    self.send_error(500, str(e))
            else:
                self.send_error(400, "Invalid URL format")
            return

        # API to delete rows
        elif '/delete_rows' in self.path:
            parts = self.path.split('/')
            if len(parts) >= 4:
                filename = urllib.parse.unquote(parts[3])
                filepath = os.path.join(DIRECTORY, 'data', filename)

                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                try:
                    data = json.loads(post_data.decode('utf-8'))
                    row_indices = data.get('row_indices', [])

                    if not row_indices:
                        self.send_error(400, "Missing 'row_indices' field")
                        return

                    if os.path.exists(filepath):
                        with open(filepath, 'r', encoding='utf-8') as f:
                            reader = csv.DictReader(f)
                            rows = list(reader)
                            headers = reader.fieldnames if reader.fieldnames else []

                        # Delete in reverse order to preserve indices
                        for idx in sorted(row_indices, reverse=True):
                            if 0 <= idx < len(rows):
                                rows.pop(idx)

                        with open(filepath, 'w', encoding='utf-8', newline='') as f:
                            writer = csv.DictWriter(f, fieldnames=headers)
                            writer.writeheader()
                            writer.writerows(rows)

                        response = {
                            'headers': headers,
                            'rows': rows
                        }

                        self.send_response(200)
                        self.send_header('Content-type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps(response).encode())
                    else:
                        self.send_error(404, "File not found")

                except Exception as e:
                    self.send_error(500, str(e))
            else:
                self.send_error(400, "Invalid URL format")
            return

        self.send_error(404, "Not found")

print(f"Serving at port {PORT}")
print(f"Open http://localhost:{PORT} in your browser")

# Allow reuse address to avoid 'Address already in use' errors on quick restarts
socketserver.TCPServer.allow_reuse_address = True

with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.server_close()
