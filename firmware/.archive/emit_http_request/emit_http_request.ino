#include <WiFi.h>
#include <HTTPClient.h>
#include "Adafruit_Thermal.h"

const char* ssid = "Stanford";
const char* url = "http://httpbin.org/get";

// Thermal printer on UART2
HardwareSerial PrinterSerial(2);
Adafruit_Thermal printer(&PrinterSerial);

static const int PRINTER_RX = 16;
static const int PRINTER_TX = 17;

bool connect_to_wifi() {
  WiFi.mode(WIFI_STA);
  
  Serial.print("Connecting to ");
  Serial.println(ssid);
  
  // Connect to open network (no password)
  WiFi.begin(ssid);
  
  // Wait for connection
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Signal strength (RSSI): ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    Serial.print("Gateway: ");
    Serial.println(WiFi.gatewayIP());
    return true;
  } else {
    Serial.println("Failed to connect.");
    Serial.print("Status code: ");
    Serial.println(WiFi.status());
    return false;
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  // Initialize thermal printer
  PrinterSerial.begin(9600, SERIAL_8N1, PRINTER_RX, PRINTER_TX);
  printer.begin();
  
  Serial.println();
  Serial.print("ESP32 MAC Address: ");
  Serial.println(WiFi.macAddress());
  
  if (!connect_to_wifi()) {
    Serial.println("Halting: no WiFi.");
    while (true) {
      delay(1000);
    }
  }
  
  // Print MAC and IP to thermal printer
  printer.println("=== ESP32 Online ===");
  printer.print("MAC: ");
  printer.println(WiFi.macAddress());
  printer.print("IP:  ");
  printer.println(WiFi.localIP());
  printer.feed(2);
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi dropped, reconnecting...");
    connect_to_wifi();
    delay(5000);
    return;
  }
  
  HTTPClient http;
  http.begin(url);
  
  Serial.print("GET ");
  Serial.print(url);
  Serial.print(" -> ");
  
  int code = http.GET();
  Serial.print("HTTP ");
  Serial.println(code);
  
  if (code == 200) {
    String body = http.getString();
    Serial.println("--- response body ---");
    Serial.println(body);
    Serial.println("--- end body ---");
    
    // Print response body to thermal printer
    printer.println(body);
    printer.feed(3);
  } else if (code > 0) {
    Serial.print("Non-200 response (skipping print). ");
    if (code == 301 || code == 302) {
      Serial.print("Redirected to: ");
      Serial.println(http.getLocation());
    } else {
      Serial.println();
    }
  } else {
    Serial.print("Request failed: ");
    Serial.println(http.errorToString(code));
  }
  
  http.end();
  delay(5000);
}