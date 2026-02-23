import 'dart:convert';
import 'galois_field.dart';
import 'reed_solomon.dart';

// --- 1. MODULATOR (Bytes to Flashlight Array) ---
List<bool> modulateTo4PPM(List<int> bytes) {
  List<bool> signal = [];
  for (int byte in bytes) {
    // Read 2 bits at a time, from highest (left) to lowest (right)
    for (int shift = 6; shift >= 0; shift -= 2) {
      int twoBits = (byte >> shift) & 0x03;

      // 4-PPM Mapping Rule: Only 1 slot out of 4 is 'true' (Light ON)
      if (twoBits == 0)
        signal.addAll([true, false, false, false]);
      else if (twoBits == 1)
        signal.addAll([false, true, false, false]);
      else if (twoBits == 2)
        signal.addAll([false, false, true, false]);
      else if (twoBits == 3) signal.addAll([false, false, false, true]);
    }
  }
  return signal;
}

// --- 2. DEMODULATOR (Camera Array to Bytes) ---
List<int> demodulateFrom4PPM(List<bool> signal) {
  List<int> bytes = [];
  // Process 16 booleans (4 pairs of 4 slots) to reconstruct 1 byte
  for (int i = 0; i < signal.length; i += 16) {
    int currentByte = 0;
    for (int j = 0; j < 4; j++) {
      int slotIndex = i + (j * 4);

      // Safety check for truncated frames
      if (slotIndex + 3 >= signal.length) break;

      // Find which of the 4 slots triggered the camera (is 'true')
      int twoBits = 0; // Default to 00 if the signal was completely destroyed
      if (signal[slotIndex + 1])
        twoBits = 1;
      else if (signal[slotIndex + 2])
        twoBits = 2;
      else if (signal[slotIndex + 3]) twoBits = 3;

      // Shift and pack the bits back into the byte
      currentByte = (currentByte << 2) | twoBits;
    }
    bytes.add(currentByte);
  }
  return bytes;
}

void main() {
  // Initialize the Galois Field math universe
  initTables();
  int nsym = 8; // Add 8 bytes of Reed-Solomon armor (can fix 4 destroyed bytes)

  print('=== TRANSMITTER PHASE ===');
  // 1. Ingest Text
  String message = "f1end_BITS";
  List<int> originalBytes = utf8.encode(message);
  print('1. Original String: $message');

  // 2. Reed-Solomon Encode
  List<int> encodedBytes = rsEncodeMessage(originalBytes, nsym);
  print('2. RS Encoded Bytes: $encodedBytes');

  // 3. Modulate to 4-PPM
  List<bool> ppmSignal = modulateTo4PPM(encodedBytes);
  print('\n3. 4-PPM Signal (First 2 Bytes / 32 Flashlight Slots):');
  // Visually print the true/false array as 1s and 0s for readability
  print(ppmSignal.sublist(0, 32).map((b) => b ? '1' : '0').join(' '));

  print('\n=== UNDERWATER ATTACK ===');
  // 4. THE ATTACK: Simulate a massive air bubble completely blocking the camera.
  // We will force 16 consecutive time-slots to 'false' (darkness).
  // This completely destroys the first 4 bytes of our signal!
  List<bool> receivedSignal = List.from(ppmSignal);
  for (int i = 0; i < 32; i++) {
    receivedSignal[i] = false;
  }
  print('🔴 Light blocked! First 32 slots forced to 0 (Darkness):');
  print(receivedSignal.sublist(0, 32).map((b) => b ? '1' : '0').join(' '));

  print('\n=== RECEIVER PHASE ===');
  // 5. Demodulate back to Bytes
  List<int> demodulatedBytes = demodulateFrom4PPM(receivedSignal);
  print('5. Demodulated Bytes (Notice the first 4 bytes are corrupted to 0!):');
  print(demodulatedBytes);

  // 6. Reed-Solomon Decode (The Rescue)
  List<int>? correctedBytes = rsCorrectMessage(demodulatedBytes, nsym);

  // 7. Bytes to Text
  if (correctedBytes != null) {
    String finalString =
        utf8.decode(correctedBytes.sublist(0, originalBytes.length));
    print('\n6. RS Corrected Bytes: $correctedBytes');
    print('🎉 7. Recovered String: $finalString');
  } else {
    print('❌ RS failed to decode! Too many errors.');
  }
}
