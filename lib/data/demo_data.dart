import 'dart:typed_data';
import 'package:flutter/material.dart';

/// All data in this file is LOCAL DEMO DATA. It is not live inventory.
class Medicine {
  final String name, strength, category, form;
  const Medicine(this.name, this.strength, this.category, this.form);
}

const List<Medicine> medicines = [];

class Product {
  final String name, category;
  final IconData icon;
  const Product(this.name, this.category, this.icon);
}

const List<Product> products = [
  Product('Digital Thermometer', 'Health Devices', Icons.thermostat_rounded),
  Product('Blood Pressure Monitor', 'Health Devices', Icons.monitor_heart_outlined),
  Product('Face Masks (Box)', 'Protection', Icons.masks_outlined),
  Product('Hand Sanitizer', 'Hygiene', Icons.clean_hands_outlined),
  Product('First Aid Kit', 'Safety', Icons.medical_services_outlined),
  Product('Adhesive Bandages', 'Safety', Icons.healing_outlined),
];

class Pharmacy {
  final String name, area, description, hours;
  final IconData icon;
  const Pharmacy(this.name, this.area, this.description, this.hours, this.icon);
}

const List<Pharmacy> pharmacies = [
  Pharmacy('City Care Pharmacy', 'Local Area',
      'Verified neighbourhood pharmacy providing prescription medicines.',
      '9:00 AM – 11:00 PM', Icons.local_pharmacy_outlined),
  Pharmacy('HealthPlus Pharmacy', 'Local Area',
      'Pharmacy with everyday medicines and healthcare products.',
      '8:00 AM – 10:00 PM', Icons.medication_liquid_outlined),
  Pharmacy('MediPoint Pharmacy', 'Local Area',
      'Licensed pharmacy providing prescription fulfillment and healthcare support.',
      '24 hours', Icons.health_and_safety_outlined),
];

class DemoLocation {
  final String label, address;
  const DemoLocation(this.label, this.address);
}

const List<DemoLocation> locations = [
  DemoLocation('Current Location', 'Select your delivery address'),
];

final ValueNotifier<DemoLocation> selectedLocation =
    ValueNotifier<DemoLocation>(locations.first);

final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

final ValueNotifier<List<Medicine>> recentlyViewed =
    ValueNotifier<List<Medicine>>([]);

void markViewed(Medicine m) {
  final list = List<Medicine>.from(recentlyViewed.value)
    ..removeWhere((e) => e.name == m.name)
    ..insert(0, m);
  recentlyViewed.value = list.take(6).toList();
}

class PrescriptionRecord {
  final DateTime date;
  final Uint8List? bytes;
  final List<String> items;
  const PrescriptionRecord(this.date, this.bytes, this.items);
}

final ValueNotifier<List<PrescriptionRecord>> prescriptionRecords =
    ValueNotifier<List<PrescriptionRecord>>([]);

class DemoNotification {
  final String title, body, time;
  const DemoNotification(this.title, this.body, this.time);
}

const List<DemoNotification> notifications = [
  DemoNotification('Welcome to DAWA',
      'Upload a prescription or explore genuine nearby pharmacy stock in real time.', 'Today'),
  DemoNotification('Pharmacist review',
      'Prescription orders should be reviewed by a qualified pharmacist before approval.', 'Today'),
  DemoNotification('Health reminder',
      'Always read the label and follow the instructions of your doctor or pharmacist.', 'Yesterday'),
];
