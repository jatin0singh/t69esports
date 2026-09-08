import 'package:flutter/material.dart';

class MemeCharacterAvatar extends StatelessWidget {
  final String avatarType;
  final double size;
  final List<Color> gradientColors;

  const MemeCharacterAvatar({
    super.key,
    required this.avatarType,
    this.size = 140,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner circular backdrop
          Container(
            width: size - 8,
            height: size - 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF0F172A),
            ),
            child: ClipOval(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle gradient glow inside circle
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          gradientColors.first.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        radius: 0.85,
                      ),
                    ),
                  ),

                  // Avatar Illustration Base
                  _buildAvatarGraphic(avatarType, size),
                ],
              ),
            ),
          ),

          // Floating Role Accessory Badge at bottom right
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: gradientColors.first,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getAccessoryIcon(avatarType),
                color: gradientColors.first,
                size: size * 0.16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAccessoryIcon(String type) {
    switch (type) {
      case 'johnny_doctor':
        return Icons.medical_services_rounded;
      case 'mia_engineer':
        return Icons.cable_rounded;
      case 'johnny_astronaut':
        return Icons.rocket_launch_rounded;
      case 'mia_dispatcher':
        return Icons.headset_mic_rounded;
      case 'johnny_plumber':
        return Icons.build_rounded;
      case 'mia_referee':
        return Icons.sports_rounded;
      case 'johnny_firefighter':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.wifi_off_rounded;
    }
  }

  Widget _buildAvatarGraphic(String type, double containerSize) {
    final isJohnny = type.startsWith('johnny');

    if (isJohnny) {
      return _buildJohnnyGraphic(type, containerSize);
    } else {
      return _buildMiaGraphic(type, containerSize);
    }
  }

  /// Stylized Johnny Sins character graphic
  Widget _buildJohnnyGraphic(String type, double containerSize) {
    Color shirtColor = const Color(0xFF00A3E0);
    IconData centerEmblem = Icons.favorite_rounded;
    String headgearText = '';

    if (type == 'johnny_doctor') {
      shirtColor = const Color(0xFF00BCD4);
      centerEmblem = Icons.healing_rounded;
      headgearText = '⚕️';
    } else if (type == 'johnny_astronaut') {
      shirtColor = const Color(0xFF9333EA);
      centerEmblem = Icons.stars_rounded;
      headgearText = '🚀';
    } else if (type == 'johnny_plumber') {
      shirtColor = const Color(0xFF10B981);
      centerEmblem = Icons.plumbing_rounded;
      headgearText = '🔧';
    } else if (type == 'johnny_firefighter') {
      shirtColor = const Color(0xFFFF5722);
      centerEmblem = Icons.local_fire_department_rounded;
      headgearText = '🚒';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Head / Face (Iconic Bald Head with subtle highlight)
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Head container
            Container(
              width: containerSize * 0.42,
              height: containerSize * 0.44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFDFBA),
                    Color(0xFFF3B78A),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Eyes & Eyebrows
                  Positioned(
                    top: containerSize * 0.16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Left Eye
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2D3748),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: containerSize * 0.12),
                        // Right Eye
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2D3748),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Confident Smirk
                  Positioned(
                    bottom: containerSize * 0.08,
                    child: Container(
                      width: containerSize * 0.14,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B4513).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Headgear badge / emoji if applicable
            if (headgearText.isNotEmpty)
              Positioned(
                top: -8,
                child: Text(
                  headgearText,
                  style: TextStyle(fontSize: containerSize * 0.14),
                ),
              ),
          ],
        ),

        const SizedBox(height: 2),

        // Shoulders / Tactical Uniform
        Container(
          width: containerSize * 0.72,
          height: containerSize * 0.32,
          decoration: BoxDecoration(
            color: shirtColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Center(
            child: Icon(
              centerEmblem,
              color: Colors.white.withValues(alpha: 0.85),
              size: containerSize * 0.16,
            ),
          ),
        ),
      ],
    );
  }

  /// Stylized Mia Khalifa character graphic
  Widget _buildMiaGraphic(String type, double containerSize) {
    Color shirtColor = const Color(0xFFFF3B5C);
    IconData centerEmblem = Icons.cable_rounded;

    if (type == 'mia_engineer') {
      shirtColor = const Color(0xFFFF7A00);
      centerEmblem = Icons.settings_input_component_rounded;
    } else if (type == 'mia_dispatcher') {
      shirtColor = const Color(0xFFEC4899);
      centerEmblem = Icons.headset_mic_rounded;
    } else if (type == 'mia_referee') {
      shirtColor = const Color(0xFF1E293B);
      centerEmblem = Icons.sports_rounded;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Hair & Head with Signature Glasses
        Stack(
          alignment: Alignment.center,
          children: [
            // Dark Long Hair background
            Container(
              width: containerSize * 0.48,
              height: containerSize * 0.48,
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),

            // Face Oval
            Container(
              width: containerSize * 0.38,
              height: containerSize * 0.42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFBD7B2),
                    Color(0xFFE8AB75),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Signature Thick Black Frame Glasses
                  Positioned(
                    top: containerSize * 0.13,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: containerSize * 0.11,
                            height: containerSize * 0.08,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D2FF).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                          Container(width: 4, height: 2, color: Colors.black),
                          Container(
                            width: containerSize * 0.11,
                            height: containerSize * 0.08,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D2FF).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Cheerful Smile
                  Positioned(
                    bottom: containerSize * 0.07,
                    child: Container(
                      width: containerSize * 0.12,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 2),

        // Tactical Outfit
        Container(
          width: containerSize * 0.70,
          height: containerSize * 0.30,
          decoration: BoxDecoration(
            color: shirtColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Center(
            child: Icon(
              centerEmblem,
              color: Colors.white.withValues(alpha: 0.9),
              size: containerSize * 0.15,
            ),
          ),
        ),
      ],
    );
  }
}
