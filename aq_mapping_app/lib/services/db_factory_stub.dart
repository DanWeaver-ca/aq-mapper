/// Fallback when neither dart:io nor web libraries are available.
/// Replaced at compile time by the io or web variant via conditional import.
void configureDatabaseFactory() {}
