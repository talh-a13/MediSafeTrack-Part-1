#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <DHT.h>

#define DHTPIN 7      // Define GPIO pin for DHT22
#define DHTTYPE DHT22 // Change sensor type to DHT22

DHT dht(DHTPIN, DHTTYPE);
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
float prev_temp = -1000;  // Initialize to an unlikely value
float prev_humidity = -1000;

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      BLEDevice::startAdvertising();
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};

void setup() {
  Serial.begin(115200);
  dht.begin();

  // Initialize BLE
  BLEDevice::init("ESP32 DHT22 Sensor");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  pCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  Serial.println("Waiting for a BLE client to connect...");
}

void loop() {
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("Failed to read from DHT sensor!");
    return;
  }

  if (deviceConnected && (temperature != prev_temp || humidity != prev_humidity)) {
    prev_temp = temperature;
    prev_humidity = humidity;

    String data = String(prev_temp) + "C, " + String(prev_humidity) + "%";
    pCharacteristic->setValue(data.c_str());
    pCharacteristic->notify();

    Serial.print("Sent over BLE → Temperature: ");
    Serial.print(prev_temp);
    Serial.print("°C, Humidity: ");
    Serial.print(prev_humidity);
    Serial.println("%");
  }

  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
  }

  oldDeviceConnected = deviceConnected;

  delay(2000);  // Wait 2 seconds before next reading
}