// Opens the local database: a file on Android/iOS, IndexedDB on web (research R5).
export 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.js_interop) 'db_factory_web.dart';
