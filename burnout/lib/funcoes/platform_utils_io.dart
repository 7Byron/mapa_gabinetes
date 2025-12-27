import 'dart:io';

bool platformIsWeb() => false;
bool platformIsAndroid() => Platform.isAndroid;
bool platformIsIOS() => Platform.isIOS;
String platformOperatingSystem() => Platform.operatingSystem;
