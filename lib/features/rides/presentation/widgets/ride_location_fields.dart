import 'package:flutter/material.dart';

class RideLocationFields extends StatelessWidget {
  const RideLocationFields({
    super.key,
    required this.pickupController,
    required this.dropoffController,
    this.onUseCurrentLocation,
    this.onDropoffSubmitted,
    this.enabled = true,
  });

  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<String>? onDropoffSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final dividerColor =
        isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section label ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Your journey',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),

        // ── Unified card with vertical connector ───────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dividerColor, width: 1.5),
          ),
          child: Column(
            children: [
              // ── Pickup row ───────────────────────────────────────
              _LocationRow(
                controller: pickupController,
                readOnly: true,
                enabled: enabled,
                hintText: 'Your pickup point',
                dotColor: const Color(0xFF15BA78), // green = origin
                dotIcon: Icons.my_location_rounded,
                action:
                    enabled
                        ? IconButton(
                          onPressed: onUseCurrentLocation,
                          icon: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: primary,
                          ),
                          tooltip: 'Refresh location',
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        : null,
              ),

              // ── Divider with connector line ──────────────────────
              Row(
                children: [
                  const SizedBox(width: 20),
                  // Dot column connector
                  SizedBox(
                    width: 20,
                    child: Center(
                      child: Container(
                        width: 1.5,
                        height: 20,
                        color: dividerColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Divider(height: 1, color: dividerColor)),
                ],
              ),

              // ── Dropoff row ──────────────────────────────────────
              _LocationRow(
                controller: dropoffController,
                readOnly: false,
                enabled: enabled,
                hintText: 'Enter destination or tap map',
                dotColor: const Color(0xFF1A6BFF), // blue = destination
                dotIcon: Icons.location_on_rounded,
                textInputAction: TextInputAction.search,
                onSubmitted: onDropoffSubmitted,
              ),
            ],
          ),
        ),

        // ── Hint chip ──────────────────────────────────────────────
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 13,
                  color:
                      isDark
                          ? const Color(0xFF8B93A7)
                          : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 5),
                Text(
                  'Tap anywhere on the map to set destination',
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        isDark
                            ? const Color(0xFF8B93A7)
                            : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal row widget
// ─────────────────────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.controller,
    required this.readOnly,
    required this.enabled,
    required this.hintText,
    required this.dotColor,
    required this.dotIcon,
    this.action,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool readOnly;
  final bool enabled;
  final String hintText;
  final Color dotColor;
  final IconData dotIcon;
  final Widget? action;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          // ── Dot indicator ────────────────────────────────────────
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withOpacity(0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Text field ───────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              enabled: enabled,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    isDark ? const Color(0xFFF1F3FA) : const Color(0xFF0D1021),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color:
                      isDark
                          ? const Color(0xFF8B93A7)
                          : const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 0,
                ),
              ),
            ),
          ),

          // ── Action button (refresh etc.) ─────────────────────────
          if (action != null)
            Padding(padding: const EdgeInsets.only(right: 8), child: action!),
        ],
      ),
    );
  }
}
