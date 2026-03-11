import 'dart:async';

class BackendException implements Exception {
  final String code;
  final String message;

  BackendException(this.code, this.message);

  @override
  String toString() => message;
}

class User {
  final String uid;
  final String? email;
  final String? displayName;

  const User({required this.uid, this.email, this.displayName});
}

class Timestamp {
  final DateTime _value;

  Timestamp._(this._value);

  factory Timestamp.now() => Timestamp._(DateTime.now());

  factory Timestamp.fromDate(DateTime date) => Timestamp._(date);

  DateTime toDate() => _value;

  String toIso8601String() => _value.toIso8601String();
}

class FieldValue {
  final String _type;

  const FieldValue._(this._type);

  static FieldValue serverTimestamp() => const FieldValue._('serverTimestamp');

  bool get isServerTimestamp => _type == 'serverTimestamp';
}

class DocumentReference {
  final String id;

  const DocumentReference(this.id);
}

class DocumentSnapshot<T extends Map<String, dynamic>> {
  final String id;
  final T _data;

  const DocumentSnapshot({required this.id, required T data}) : _data = data;

  T data() => _data;

  dynamic operator [](String key) => _data[key];
}

class QueryDocumentSnapshot<T extends Map<String, dynamic>>
    extends DocumentSnapshot<T> {
  const QueryDocumentSnapshot({required super.id, required super.data});
}

class QuerySnapshot<T extends Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<T>> docs;

  const QuerySnapshot({required this.docs});
}

extension StreamListToQuerySnapshot on Stream<List<Map<String, dynamic>>> {
  Stream<QuerySnapshot<Map<String, dynamic>>> toQuerySnapshot() {
    return map(
      (rows) => QuerySnapshot<Map<String, dynamic>>(
        docs: rows
            .map(
              (row) => QueryDocumentSnapshot<Map<String, dynamic>>(
                id: row['id'].toString(),
                data: row,
              ),
            )
            .toList(),
      ),
    );
  }
}
