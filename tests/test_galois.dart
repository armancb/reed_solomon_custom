import '../lib/galois_field.dart';
import '../lib/reed_solomon.dart';

void main() {
  // Initialize GF(2^8) tables with primitive polynomial 0x11D
  initTables();
  print('✅ initTables() succeeded');
  print('   GF_LOG_SIZE = $GF_LOG_SIZE (expected 256)');
  print('   GF_EXP_SIZE = $GF_EXP_SIZE (expected 512)');

  // Basic GF arithmetic checks
  assert(gfMultiply(0, 100) == 0, 'multiply by 0 should be 0');
  assert(gfMultiply(1, 1) == 1, '1*1 should be 1');
  assert(gfDivide(0, 5) == 0, '0/5 should be 0');

  // Verify inverse: x * inv(x) == 1 for all x in 1..255
  for (int x = 1; x < 256; x++) {
    int inv = gfInverse(x);
    assert(
      gfMultiply(x, inv) == 1,
      'x=$x: x * inv(x) should be 1, got ${gfMultiply(x, inv)}',
    );
  }
  print('✅ GF inverse check passed for all elements 1..255');

  // Reed-Solomon encode/decode round-trip test
  int nsym = 10; // 10 error correction symbols
  List<int> message = [
    0x40,
    0xD2,
    0x75,
    0x47,
    0x76,
    0x17,
    0x32,
    0x06,
    0x27,
    0x26,
    0x96,
    0xC6,
    0xC6,
    0x96,
    0x70,
    0xEC,
  ];
  print('\n📨 Original message: $message');

  List<int> encoded = rsEncodeMessage(message, nsym);
  print('📦 Encoded (${encoded.length} bytes): $encoded');
  assert(
    encoded.length == message.length + nsym,
    'encoded length should be msg + nsym',
  );

  // Verify the ECC: decoding a clean message should return it unchanged
  List<int>? decoded = rsCorrectMessage(List<int>.of(encoded), nsym);
  assert(decoded != null, 'decoding a clean message should not fail');
  for (int i = 0; i < message.length; i++) {
    assert(
      decoded![i] == message[i],
      'decoded[$i] mismatch: ${decoded[i]} != ${message[i]}',
    );
  }
  print('✅ Clean decode round-trip passed');

  // Introduce errors and verify correction
  List<int> corrupted = List<int>.of(encoded);
  corrupted[0] ^= 0xFF; // flip bits in first byte
  corrupted[5] ^= 0xAB; // flip bits in sixth byte
  print('\n🔴 Corrupted bytes at positions 0 and 5');
  print('   Corrupted: $corrupted');

  List<int>? corrected = rsCorrectMessage(corrupted, nsym);
  assert(
    corrected != null,
    'correction should succeed with 2 errors and nsym=10',
  );
  for (int i = 0; i < encoded.length; i++) {
    assert(
      corrected![i] == encoded[i],
      'corrected[$i] mismatch: ${corrected[i]} != ${encoded[i]}',
    );
  }
  print('✅ Error correction passed — recovered original message');

  print('\n🎉 All tests passed!');
}
