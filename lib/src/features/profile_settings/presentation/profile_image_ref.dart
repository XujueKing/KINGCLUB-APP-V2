import 'dart:io';

import 'package:flutter/material.dart';

ImageProvider<Object> profileImageProvider(String reference) {
  if (reference.startsWith('assets/')) {
    return AssetImage(reference);
  }
  return FileImage(File(reference));
}
