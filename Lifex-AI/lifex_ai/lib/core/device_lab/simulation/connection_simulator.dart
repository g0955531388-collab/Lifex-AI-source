/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: connection_simulator.dart
/// اتصال ناجح ليس الافتراضي الوحيد.
/// =============================================================
library lifex_ai.core.device_lab.connection_simulator;

class ConnectionSimulator {
  ConnectionSimulator({
    this.latency = Duration.zero,
    this.packetLoss = 0,
    this.simulateDisconnect = false,
    this.weakSignal = false,
    this.timeout = false,
    this.authFailure = false,
    this.malformed = false,
  });

  Duration latency;
  double packetLoss;
  bool simulateDisconnect;
  bool weakSignal;
  bool timeout;
  bool authFailure;
  bool malformed;

  bool get dropNow {
    if (simulateDisconnect) return true;
    if (packetLoss <= 0) return false;
    return packetLoss >= 1.0;
  }
}

class BatterySimulator {
  BatterySimulator({this.percent = 100, this.low = false});

  int percent;
  bool low;

  void drainTo(int value) {
    percent = value.clamp(0, 100);
    low = percent <= 15;
  }
}

class FailureSimulator {
  FailureSimulator(this.links);

  final Map<String, ConnectionSimulator> links;

  Future<void> disconnectDevice(String deviceId) async {
    links[deviceId]?.simulateDisconnect = true;
  }

  Future<void> dropPackets(String deviceId) async {
    links[deviceId]?.packetLoss = 1;
  }

  Future<void> delayResponses(String deviceId, Duration delay) async {
    links[deviceId]?.latency = delay;
  }

  Future<void> simulateLowBattery(BatterySimulator battery) async {
    battery.drainTo(8);
  }

  Future<void> clear(String deviceId) async {
    final s = links[deviceId];
    if (s == null) return;
    s.simulateDisconnect = false;
    s.packetLoss = 0;
    s.latency = Duration.zero;
    s.timeout = false;
    s.authFailure = false;
    s.malformed = false;
  }
}
