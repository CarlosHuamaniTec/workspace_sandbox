import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart' as ffi_helpers;

/// Opaque handle to a native process instance.
///
/// The concrete layout is defined in the C/C++ implementation.
base class ProcessHandle extends ffi.Opaque {}

/// FFI representation of the options passed to the native core.
final class WorkspaceOptionsC extends ffi.Struct {
  external ffi.Pointer<ffi_helpers.Utf8> command_line;
  external ffi.Pointer<ffi_helpers.Utf8> cwd;

  @ffi.Bool()
  external bool sandbox;

  external ffi.Pointer<ffi_helpers.Utf8> id;
}

// C function type signatures.

typedef StartC = ffi.Pointer<ProcessHandle> Function(
  ffi.Pointer<WorkspaceOptionsC>,
);
typedef StartDart = ffi.Pointer<ProcessHandle> Function(
  ffi.Pointer<WorkspaceOptionsC>,
);

typedef ReadC = ffi.Int32 Function(
  ffi.Pointer<ProcessHandle>,
  ffi.Pointer<ffi.Uint8>,
  ffi.Int32,
);
typedef ReadDart = int Function(
  ffi.Pointer<ProcessHandle>,
  ffi.Pointer<ffi.Uint8>,
  int,
);

typedef IsRunningC = ffi.Int32 Function(
  ffi.Pointer<ProcessHandle>,
  ffi.Pointer<ffi.Int32>,
);
typedef IsRunningDart = int Function(
  ffi.Pointer<ProcessHandle>,
  ffi.Pointer<ffi.Int32>,
);

typedef KillC = ffi.Void Function(ffi.Pointer<ProcessHandle>);
typedef KillDart = void Function(ffi.Pointer<ProcessHandle>);

typedef FreeC = ffi.Void Function(ffi.Pointer<ProcessHandle>);
typedef FreeDart = void Function(ffi.Pointer<ProcessHandle>);
