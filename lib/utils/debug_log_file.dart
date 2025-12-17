// Exporta a implementação correta baseado na plataforma
export 'debug_log_file_stub.dart'
    if (dart.library.io) 'debug_log_file_io.dart';

