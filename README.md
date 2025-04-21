<h3 align="center">MediSafeTrack: Securing & Tracking Pharmaceutical Cold Storage using IoT</h3>

<h4>Overview</h4>
MediSafeTrack is an automated cold storage monitoring system designed to track and secure temperature-sensitive pharmaceutical products throughout the supply chain. This system ensures regulatory compliance and maintains the efficacy of critical medications, particularly in regions with unstable infrastructure.

## Problem Statement
Temperature-sensitive pharmaceuticals like vaccines, insulin, and biologics require precise environmental conditions to maintain their potency. Exposure to inappropriate temperatures can compromise their effectiveness, leading to public health risks and financial losses. Traditional monitoring systems often fail to provide:
- **Real-time temperature tracking**
- **Uninterrupted monitoring during power outages** 
- **Secure data retention and transmission**
- **Regulatory compliance documentation** 

## Solution Architecture
MediSafeTrack implements a hierarchical monitoring system with three main components:

1. Slave Devices
   - **Hardware**: ESP32 microcontrollers with DHT22 temperature/humidity sensors
   - **Power**: Battery-operated for continuous function during power outages
   - **Communication**: Bluetooth Low Energy (BLE) with Reliable Data Transfer (RDT) protocol
   - **Visual Indicators**: Blue LED for connection status (flashing while connecting, steady when connected), Red LED for power status (on when active, off when unusable)
   
2. Master Device (Mobile Application)
    - **Platform**: Developed using Flutter
    <h4>Functions</h4>
    - Collects data from multiple slave devices via Bluetooth
    - Displays real-time temperature readings
    - Stores data locally during connectivity disruptions
    - Synchronizes with cloud infrastructure when connection is restored
    - Provides intuitive monitoring interface

3. Cloud Infrastructure
    - **Server**: Virtual Private Server (VPS) running Ubuntu
    - **Data Management**: Secure storage, processing, and access control
    - **User Interfaces**:
      - **Warehouse Control Center Interface**: For facility staff to monitor conditions in real-time
      - **Drug Inspector Interface**: For regulatory personnel to verify compliance

## Key Features
- **Continuous Monitoring**: 24/7 temperature and humidity tracking
- **Offline Resilience**: Local data storage during power or network outages
- **Automatic Synchronization**: Data transferred to cloud when connectivity is restored
- **Visual Alert System**: LED indicators for connection and power status
- **Role-Based Access**: Separate interfaces for regulatory inspectors and warehouse personnel
- **Scalable Architecture**: Multiple slave devices can be managed by a single master
- **Compliance Support**: Automated record-keeping for regulatory requirements

## Benefits
- **Ensures Drug Efficacy**: Maintains proper storage conditions for temperature-sensitive pharmaceuticals
- **Reduces Wastage**: Early detection of temperature deviations allows for prompt corrective action
- **Regulatory Compliance**: Automated documentation for inspection purposes
- **Enhanced Reliability**: Battery-powered operation ensures continuous monitoring
- **Cost-Effective**: Optimized for deployment in resource-constrained settings

## Implementation Considerations
- **Installation**: Position slave devices strategically throughout storage areas
- **Connectivity**: Ensure Bluetooth range between slave and master devices
- **Power Management**: Regular battery checks for slave devices
- **Data Security**: Implement proper access controls for the mobile applications
- **Training**: Staff should be trained on monitoring procedures and response protocols

## Target Use Cases
- Pharmaceutical warehouses and distribution centers
- Hospital pharmacy departments
- Vaccine storage facilities
- Pharmaceutical transportation and logistics
- Rural healthcare centers with unreliable power infrastructure

## Technical Specifications
- **Operating Temperature Range**: Accommodates pharmaceutical storage requirements
- **Data Transmission Protocol**: Reliable Data Transfer (RDT) over Bluetooth
- **Battery Life**: Extended operation during power outages
- **Cloud Security**: Encrypted API communication
- **Application Compatibility**: Android mobile devices

## Credits
This project was developed by Talha Hussain and Ibrahim Bhatti , inspired by the goal of ensuring pharmaceutical integrity and public health safety in regions with developing infrastructure.
