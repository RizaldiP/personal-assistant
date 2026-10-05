/// Sumber waktu yang bisa disuntikkan agar logika tanggal/jam dapat diuji
/// secara deterministik.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Clock tetap untuk test.
class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  set value(DateTime value) => _now = value;

  @override
  DateTime now() => _now;
}
