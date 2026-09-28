import 'package:flutter/material.dart';

import '../../../data/models/app_event.dart';
import '../../../data/repositories/event_repository.dart';

class EditEventController {
  static const int titleMaxLength = 80;
  static const int detailsMaxLength = 1000;
  static const int locationMaxLength = 120;
  static const int notesMaxLength = 500;

  final titleController = TextEditingController();
  final detailsController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();

  final EventRepository _eventRepository;

  bool isSubmitting = false;
  DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));

  EditEventController({
    EventRepository? eventRepository,
  }) : _eventRepository = eventRepository ?? EventRepository();

  void fillFromEvent(AppEvent event) {
    titleController.text = event.title;
    detailsController.text = event.details;
    locationController.text = event.location;
    notesController.text = event.notes;
    selectedDateTime = DateTime.fromMillisecondsSinceEpoch(event.eventAt);
  }

  String? validate() {
    final title = titleController.text.trim();
    final details = detailsController.text.trim();
    final location = locationController.text.trim();
    final notes = notesController.text.trim();

    if (title.isEmpty) {
      return 'events.validation.title_required';
    }

    if (title.length > titleMaxLength) {
      return 'events.validation.title_too_long';
    }

    if (details.isEmpty) {
      return 'events.validation.details_required';
    }

    if (details.length > detailsMaxLength) {
      return 'events.validation.details_too_long';
    }

    if (location.isEmpty) {
      return 'events.validation.location_required';
    }

    if (location.length > locationMaxLength) {
      return 'events.validation.location_too_long';
    }

    if (notes.length > notesMaxLength) {
      return 'events.validation.notes_too_long';
    }

    if (selectedDateTime.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      return 'events.validation.time_invalid';
    }

    return null;
  }

  Future<String?> submit(String eventId) async {
    final validationError = validate();
    if (validationError != null) {
      return validationError;
    }

    isSubmitting = true;
    try {
      return await _eventRepository.updateEvent(
        eventId: eventId,
        title: titleController.text.trim(),
        details: detailsController.text.trim(),
        location: locationController.text.trim(),
        notes: notesController.text.trim(),
        eventAt: selectedDateTime.millisecondsSinceEpoch,
      );
    } finally {
      isSubmitting = false;
    }
  }

  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    locationController.dispose();
    notesController.dispose();
  }
}
