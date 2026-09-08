import 'package:flutter/material.dart';

class OfflineMemeProfile {
  final String id;
  final String characterName;
  final String alias;
  final String profession;
  final String badge;
  final IconData badgeIcon;
  final String funnyQuote;
  final String advice;
  final List<Color> gradientColors;
  final String specialty;
  final String funnyFact;
  final String avatarType; // 'johnny_doctor', 'mia_engineer', 'johnny_astronaut', 'mia_dispatcher', 'johnny_plumber', 'mia_referee', 'johnny_firefighter'

  const OfflineMemeProfile({
    required this.id,
    required this.characterName,
    required this.alias,
    required this.profession,
    required this.badge,
    required this.badgeIcon,
    required this.funnyQuote,
    required this.advice,
    required this.gradientColors,
    required this.specialty,
    required this.funnyFact,
    required this.avatarType,
  });

  static const List<OfflineMemeProfile> allProfiles = [
    OfflineMemeProfile(
      id: 'johnny_doc',
      characterName: 'Johnny Sins',
      alias: 'Dr. Sins',
      profession: 'Chief Wi-Fi Surgeon & Network Medic',
      badge: 'MEDIC SQUAD',
      badgeIcon: Icons.medical_services_rounded,
      funnyQuote:
          'I\'ve performed 400 heart surgeries, delivered 200 babies, and solved complex anatomy... but even my medical degree can\'t find a pulse in your Wi-Fi signal!',
      advice: 'Check your Wi-Fi switch, toggle Airplane Mode, or turn on Mobile Data.',
      gradientColors: [Color(0xFF00D2FF), Color(0xFF0288D1)],
      specialty: 'Emergency Data Resuscitation',
      funnyFact: 'Has 47 different doctor degrees, but zero internet bars right now.',
      avatarType: 'johnny_doctor',
    ),
    OfflineMemeProfile(
      id: 'mia_glasses',
      characterName: 'Mia Khalifa',
      alias: 'Engineer Mia',
      profession: 'Lead Fiber Optics & Signal Specialist',
      badge: 'OPTICS DIVISION',
      badgeIcon: Icons.visibility_rounded,
      funnyQuote:
          'Put on your glasses and look closely! The router is completely unplugged. I checked every optical fiber and found zero packets flowing.',
      advice: 'Ensure your router cables are plugged in or your mobile SIM has active data.',
      gradientColors: [Color(0xFFFF3B5C), Color(0xFFFF7A00)],
      specialty: 'High-Bandwidth Fiber Routing',
      funnyFact: 'Wears signature black-frame glasses to spot disconnected cables instantly.',
      avatarType: 'mia_engineer',
    ),
    OfflineMemeProfile(
      id: 'johnny_astro',
      characterName: 'Johnny Sins',
      alias: 'Commander Johnny',
      profession: 'Deep Space Satellite Navigator',
      badge: 'COSMIC OPS',
      badgeIcon: Icons.rocket_launch_rounded,
      funnyQuote:
          'Houston, we have an offline emergency! I\'m floating in orbit and your internet signal has vanished into deep space.',
      advice: 'Align yourself with a good 4G/5G tower or restart your connection.',
      gradientColors: [Color(0xFF6366F1), Color(0xFF9333EA)],
      specialty: 'Orbital Packet Transmission',
      funnyFact: 'First astronaut to attempt playing Free Fire from the International Space Station.',
      avatarType: 'johnny_astronaut',
    ),
    OfflineMemeProfile(
      id: 'mia_dispatch',
      characterName: 'Mia Khalifa',
      alias: 'Dispatcher Mia',
      profession: 'Senior Traffic & Heavy Load Director',
      badge: 'TRAFFIC CONTROL',
      badgeIcon: Icons.bolt_rounded,
      funnyQuote:
          'I know everything there is to know about handling extreme traffic and high loads, but your connection just went completely silent!',
      advice: 'Hit the Retry button below once your internet is back up.',
      gradientColors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
      specialty: 'Overload Prevention & Congestion Control',
      funnyFact: 'Expert in managing millions of incoming connections without breaking a sweat.',
      avatarType: 'mia_dispatcher',
    ),
    OfflineMemeProfile(
      id: 'johnny_plumber',
      characterName: 'Johnny Sins',
      alias: 'Master Johnny',
      profession: 'Chief Data Pipe & Packet Plumber',
      badge: 'PIPELINE SPECIALIST',
      badgeIcon: Icons.plumbing_rounded,
      funnyQuote:
          'I\'ve inspected every pipe in the building. Looks like you\'ve got a massive data leak and not a single byte is coming through!',
      advice: 'Check your DNS settings or switch between Wi-Fi and Cellular data.',
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
      specialty: 'High-Pressure Pipe & Port Repair',
      funnyFact: 'Can fix any leak in 5 minutes, whether in the sink or the router.',
      avatarType: 'johnny_plumber',
    ),
    OfflineMemeProfile(
      id: 'mia_referee',
      characterName: 'Mia Khalifa',
      alias: 'Ref Mia',
      profession: 'Tactical Esports Referee & Arbiter',
      badge: 'MATCH ARBITER',
      badgeIcon: Icons.sports_rounded,
      funnyQuote:
          'Whistle blown! You\'ve been red-carded by your internet service provider. Reconnect now before your lobby starts without you!',
      advice: 'Reconnect fast so you don\'t forfeit your tournament slot.',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      specialty: 'Esports Fair Play & Connection Penalty Enforcement',
      funnyFact: 'Never misses a foul or a ping spike above 999ms.',
      avatarType: 'mia_referee',
    ),
    OfflineMemeProfile(
      id: 'johnny_fire',
      characterName: 'Johnny Sins',
      alias: 'Captain Johnny',
      profession: 'Emergency Server Firefighter',
      badge: 'HEAT RESPONSE',
      badgeIcon: Icons.local_fire_department_rounded,
      funnyQuote:
          'The router was running so hot it caught fire! I extinguished the blaze with a fire hose, but now we need you to turn the data back on.',
      advice: 'Let your device cool down for a second and tap Reconnect.',
      gradientColors: [Color(0xFFFF5722), Color(0xFFC62828)],
      specialty: 'Overheating Server Suppression',
      funnyFact: 'Rushed into burning server rooms wearing full firefighter gear.',
      avatarType: 'johnny_firefighter',
    ),
  ];

  static OfflineMemeProfile getRandom([String? excludeId]) {
    final list = excludeId == null
        ? List<OfflineMemeProfile>.from(allProfiles)
        : allProfiles.where((p) => p.id != excludeId).toList();
    if (list.isEmpty) return allProfiles.first;
    list.shuffle();
    return list.first;
  }
}
