import 'dart:async';

/// Menggabungkan dua stream: memancarkan hasil [combiner] begitu **kedua**
/// stream sudah pernah menghasilkan nilai, lalu setiap kali salah satunya
/// memancarkan nilai baru.
Stream<R> combineLatest<T1, T2, R>(
  Stream<T1> first,
  Stream<T2> second,
  R Function(T1, T2) combiner,
) {
  late T1 valueA;
  late T2 valueB;
  var haveA = false;
  var haveB = false;

  StreamSubscription<T1>? subA;
  StreamSubscription<T2>? subB;
  late StreamController<R> controller;

  controller = StreamController<R>(
    onListen: () {
      subA = first.listen((value) {
        valueA = value;
        haveA = true;
        if (haveB) controller.add(combiner(valueA, valueB));
      });
      subB = second.listen((value) {
        valueB = value;
        haveB = true;
        if (haveA) controller.add(combiner(valueA, valueB));
      });
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await controller.close();
    },
  );

  return controller.stream;
}
