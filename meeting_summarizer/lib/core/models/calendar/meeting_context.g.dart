// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meeting_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MeetingContext _$MeetingContextFromJson(Map<String, dynamic> json) =>
    MeetingContext(
      event: CalendarEvent.fromJson(json['event'] as Map<String, dynamic>),
      type: $enumDecode(_$MeetingTypeEnumMap, json['type']),
      participants: (json['participants'] as List<dynamic>?)
              ?.map(
                  (e) => MeetingParticipant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      agendaItems: (json['agendaItems'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toSet() ??
          const {},
      expectedDuration:
          Duration(microseconds: (json['expectedDuration'] as num).toInt()),
      preparationNotes: json['preparationNotes'] as String?,
      previousMeetingIds: (json['previousMeetingIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      priority:
          $enumDecodeNullable(_$MeetingPriorityEnumMap, json['priority']) ??
              MeetingPriority.normal,
      shouldAutoRecord: json['shouldAutoRecord'] as bool? ?? false,
      recordingPreferences: json['recordingPreferences'] == null
          ? null
          : RecordingPreferences.fromJson(
              json['recordingPreferences'] as Map<String, dynamic>),
      summaryDistribution: json['summaryDistribution'] == null
          ? null
          : SummaryDistribution.fromJson(
              json['summaryDistribution'] as Map<String, dynamic>),
      virtualMeetingInfo: json['virtualMeetingInfo'] == null
          ? null
          : VirtualMeetingInfo.fromJson(
              json['virtualMeetingInfo'] as Map<String, dynamic>),
      location: json['location'] == null
          ? null
          : MeetingLocation.fromJson(json['location'] as Map<String, dynamic>),
      detectionConfidence:
          (json['detectionConfidence'] as num?)?.toDouble() ?? 0.0,
      extractedAt: DateTime.parse(json['extractedAt'] as String),
    );

Map<String, dynamic> _$MeetingContextToJson(MeetingContext instance) =>
    <String, dynamic>{
      'event': instance.event,
      'type': _$MeetingTypeEnumMap[instance.type]!,
      'participants': instance.participants,
      'agendaItems': instance.agendaItems,
      'tags': instance.tags.toList(),
      'expectedDuration': instance.expectedDuration.inMicroseconds,
      'preparationNotes': instance.preparationNotes,
      'previousMeetingIds': instance.previousMeetingIds,
      'priority': _$MeetingPriorityEnumMap[instance.priority]!,
      'shouldAutoRecord': instance.shouldAutoRecord,
      'recordingPreferences': instance.recordingPreferences,
      'summaryDistribution': instance.summaryDistribution,
      'virtualMeetingInfo': instance.virtualMeetingInfo,
      'location': instance.location,
      'detectionConfidence': instance.detectionConfidence,
      'extractedAt': instance.extractedAt.toIso8601String(),
    };

const _$MeetingTypeEnumMap = {
  MeetingType.standup: 'standup',
  MeetingType.oneOnOne: 'oneOnOne',
  MeetingType.teamMeeting: 'teamMeeting',
  MeetingType.presentation: 'presentation',
  MeetingType.interview: 'interview',
  MeetingType.training: 'training',
  MeetingType.brainstorming: 'brainstorming',
  MeetingType.retrospective: 'retrospective',
  MeetingType.planning: 'planning',
  MeetingType.review: 'review',
  MeetingType.other: 'other',
};

const _$MeetingPriorityEnumMap = {
  MeetingPriority.low: 'low',
  MeetingPriority.normal: 'normal',
  MeetingPriority.high: 'high',
  MeetingPriority.urgent: 'urgent',
};

MeetingParticipant _$MeetingParticipantFromJson(Map<String, dynamic> json) =>
    MeetingParticipant(
      name: json['name'] as String,
      email: json['email'] as String,
      role: $enumDecodeNullable(_$ParticipantRoleEnumMap, json['role']) ??
          ParticipantRole.attendee,
      isOptional: json['isOptional'] as bool? ?? false,
      hasAccepted: json['hasAccepted'] as bool? ?? false,
    );

Map<String, dynamic> _$MeetingParticipantToJson(MeetingParticipant instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'role': _$ParticipantRoleEnumMap[instance.role]!,
      'isOptional': instance.isOptional,
      'hasAccepted': instance.hasAccepted,
    };

const _$ParticipantRoleEnumMap = {
  ParticipantRole.organizer: 'organizer',
  ParticipantRole.presenter: 'presenter',
  ParticipantRole.attendee: 'attendee',
  ParticipantRole.optional: 'optional',
  ParticipantRole.resource: 'resource',
};

VirtualMeetingInfo _$VirtualMeetingInfoFromJson(Map<String, dynamic> json) =>
    VirtualMeetingInfo(
      platform: $enumDecode(_$VirtualPlatformEnumMap, json['platform']),
      meetingId: json['meetingId'] as String,
      joinUrl: json['joinUrl'] as String,
      dialInNumber: json['dialInNumber'] as String?,
      accessCode: json['accessCode'] as String?,
      password: json['password'] as String?,
    );

Map<String, dynamic> _$VirtualMeetingInfoToJson(VirtualMeetingInfo instance) =>
    <String, dynamic>{
      'platform': _$VirtualPlatformEnumMap[instance.platform]!,
      'meetingId': instance.meetingId,
      'joinUrl': instance.joinUrl,
      'dialInNumber': instance.dialInNumber,
      'accessCode': instance.accessCode,
      'password': instance.password,
    };

const _$VirtualPlatformEnumMap = {
  VirtualPlatform.zoom: 'zoom',
  VirtualPlatform.teams: 'teams',
  VirtualPlatform.meet: 'meet',
  VirtualPlatform.webex: 'webex',
  VirtualPlatform.skype: 'skype',
  VirtualPlatform.other: 'other',
};

MeetingLocation _$MeetingLocationFromJson(Map<String, dynamic> json) =>
    MeetingLocation(
      name: json['name'] as String,
      address: json['address'] as String?,
      building: json['building'] as String?,
      room: json['room'] as String?,
      floor: json['floor'] as String?,
      type: $enumDecodeNullable(_$LocationTypeEnumMap, json['type']) ??
          LocationType.office,
    );

Map<String, dynamic> _$MeetingLocationToJson(MeetingLocation instance) =>
    <String, dynamic>{
      'name': instance.name,
      'address': instance.address,
      'building': instance.building,
      'room': instance.room,
      'floor': instance.floor,
      'type': _$LocationTypeEnumMap[instance.type]!,
    };

const _$LocationTypeEnumMap = {
  LocationType.office: 'office',
  LocationType.conference: 'conference',
  LocationType.home: 'home',
  LocationType.external: 'external',
  LocationType.virtual: 'virtual',
};

RecordingPreferences _$RecordingPreferencesFromJson(
        Map<String, dynamic> json) =>
    RecordingPreferences(
      autoStart: json['autoStart'] as bool? ?? false,
      autoStop: json['autoStop'] as bool? ?? false,
      recordAudio: json['recordAudio'] as bool? ?? true,
      recordVideo: json['recordVideo'] as bool? ?? false,
      audioQuality: json['audioQuality'] as String? ?? 'high',
      enhanceAudio: json['enhanceAudio'] as bool? ?? true,
    );

Map<String, dynamic> _$RecordingPreferencesToJson(
        RecordingPreferences instance) =>
    <String, dynamic>{
      'autoStart': instance.autoStart,
      'autoStop': instance.autoStop,
      'recordAudio': instance.recordAudio,
      'recordVideo': instance.recordVideo,
      'audioQuality': instance.audioQuality,
      'enhanceAudio': instance.enhanceAudio,
    };

SummaryDistribution _$SummaryDistributionFromJson(Map<String, dynamic> json) =>
    SummaryDistribution(
      enabled: json['enabled'] as bool? ?? false,
      recipients: (json['recipients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      includeTranscript: json['includeTranscript'] as bool? ?? true,
      includeActionItems: json['includeActionItems'] as bool? ?? true,
      deliveryMethod: json['deliveryMethod'] as String? ?? 'email',
      delayAfterMeeting: json['delayAfterMeeting'] == null
          ? const Duration(minutes: 15)
          : Duration(microseconds: (json['delayAfterMeeting'] as num).toInt()),
    );

Map<String, dynamic> _$SummaryDistributionToJson(
        SummaryDistribution instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'recipients': instance.recipients,
      'includeTranscript': instance.includeTranscript,
      'includeActionItems': instance.includeActionItems,
      'deliveryMethod': instance.deliveryMethod,
      'delayAfterMeeting': instance.delayAfterMeeting.inMicroseconds,
    };
