from django.test import SimpleTestCase


class PublicEndpointTests(SimpleTestCase):
    def test_health_endpoint_reports_ready(self):
        response = self.client.get("/healthz")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, b"OK")

    def test_homepage_is_available(self):
        response = self.client.get("/")

        self.assertEqual(response.status_code, 200)
