// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CalendarEvent _$CalendarEventFromJson(Map<String, dynamic> json) =>
    CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String?,
      organizer: json['organizer'] == null
          ? null
          : EventOrganizer.fromJson(json['organizer'] as Map<String, dynamic>),
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((e) => EventAttendee.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      provider: $enumDecode(_$CalendarProviderEnumMap, json['provider']),
      isAllDay: json['isAllDay'] as bool? ?? false,
      recurrenceRule: json['recurrenceRule'] as String?,
      isMeeting: json['isMeeting'] as bool? ?? false,
      meetingConfidence: (json['meetingConfidence'] as num?)?.toDouble() ?? 0.0,
      meetingUrl: json['meetingUrl'] as String?,
      status: $enumDecodeNullable(_$EventStatusEnumMap, json['status']) ??
          EventStatus.confirmed,
      timezone: json['timezone'] as String? ?? 'UTC',
      metadata: json['metadata'] as Map<String, dynamic>?,
      lastModified: json['lastModified'] == null
          ? null
          : DateTime.parse(json['lastModified'] as String),
    );

Map<String, dynamic> _$CalendarEventToJson(CalendarEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'location': instance.location,
      'organizer': instance.organizer,
      'attendees': instance.attendees,
      'provider': _$CalendarProviderEnumMap[instance.provider]!,
      'isAllDay': instance.isAllDay,
      'recurrenceRule': instance.recurrenceRule,
      'isMeeting': instance.isMeeting,
      'meetingConfidence': instance.meetingConfidence,
      'meetingUrl': instance.meetingUrl,
      'status': _$EventStatusEnumMap[instance.status]!,
      'timezone': instance.timezone,
      'metadata': instance.metadata,
      'lastModified': instance.lastModified?.toIso8601String(),
    };

const _$CalendarProviderEnumMap = {
  CalendarProvider.googleCalendar: 'googleCalendar',
  CalendarProvider.outlookCalendar: 'outlookCalendar',
  CalendarProvider.appleCalendar: 'appleCalendar',
  CalendarProvider.deviceCalendar: 'deviceCalendar',
};

const _$EventStatusEnumMap = {
  EventStatus.confirmed: 'confirmed',
  EventStatus.tentative: 'tentative',
  EventStatus.cancelled: 'cancelled',
};

EventOrganizer _$EventOrganizerFromJson(Map<String, dynamic> json) =>
    EventOrganizer(
      name: json['name'] as String?,
      email: json['email'] as String?,
      isCurrentUser: json['isCurrentUser'] as bool?,
    );

Map<String, dynamic> _$EventOrganizerToJson(EventOrganizer instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'isCurrentUser': instance.isCurrentUser,
    };

EventAttendee _$EventAttendeeFromJson(Map<String, dynamic> json) =>
    EventAttendee(
      name: json['name'] as String?,
      email: json['email'] as String?,
      status: $enumDecodeNullable(_$AttendeeStatusEnumMap, json['status']) ??
          AttendeeStatus.needsAction,
      type: $enumDecodeNullable(_$AttendeeTypeEnumMap, json['type']) ??
          AttendeeType.required,
      isOrganizer: json['isOrganizer'] as bool? ?? false,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );

Map<String, dynamic> _$EventAttendeeToJson(EventAttendee instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'status': _$AttendeeStatusEnumMap[instance.status]!,
      'type': _$AttendeeTypeEnumMap[instance.type]!,
      'isOrganizer': instance.isOrganizer,
      'isCurrentUser': instance.isCurrentUser,
    };

const _$AttendeeStatusEnumMap = {
  AttendeeStatus.needsAction: 'needsAction',
  AttendeeStatus.accepted: 'accepted',
  AttendeeStatus.declined: 'declined',
  AttendeeStatus.tentative: 'tentative',
};

const _$AttendeeTypeEnumMap = {
  AttendeeType.required: 'required',
  AttendeeType.optional: 'optional',
  AttendeeType.resource: 'resource',
};
