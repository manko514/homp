import 'package:flutter_test/flutter_test.dart';

import 'services/ticket_storage_test.dart' as ticket_storage;
import 'services/offline_queue_test.dart' as offline_queue;
import 'models/ticket_model_test.dart' as ticket_model;
import 'models/booking_model_test.dart' as booking_model;

void main() {
  ticket_storage.main();
  offline_queue.main();
  ticket_model.main();
  booking_model.main();
}
