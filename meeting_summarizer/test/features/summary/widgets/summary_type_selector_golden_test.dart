/// Golden file tests for SummaryTypeSelector widget
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:meeting_summarizer/features/summary/presentation/widgets/summary_type_selector.dart';
import 'package:meeting_summarizer/core/models/database/summary.dart';
import '../../../utils/golden_test_helpers.dart';

void main() {
  group('SummaryTypeSelector Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelpers.initialize();
    });

    testGoldens('SummaryTypeSelector - Different Selected Types', (
      tester,
    ) async {
      final typeScenarios = {
        'brief_selected': SummaryTypeSelector(
          selectedType: SummaryType.brief,
          onTypeChanged: (type) {},
          enabled: true,
        ),
        'detailed_selected': SummaryTypeSelector(
          selectedType: SummaryType.detailed,
          onTypeChanged: (type) {},
          enabled: true,
        ),
        'bullet_points_selected': SummaryTypeSelector(
          selectedType: SummaryType.bulletPoints,
          onTypeChanged: (type) {},
          enabled: true,
        ),
        'action_items_selected': SummaryTypeSelector(
          selectedType: SummaryType.actionItems,
          onTypeChanged: (type) {},
          enabled: true,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'summary_type_selector_types',
        scenarios: typeScenarios,
      );
    });

    testGoldens('SummaryTypeSelector - Enabled vs Disabled States', (
      tester,
    ) async {
      final stateScenarios = {
        'enabled': SummaryTypeSelector(
          selectedType: SummaryType.detailed,
          onTypeChanged: (type) {},
          enabled: true,
        ),
        'disabled': SummaryTypeSelector(
          selectedType: SummaryType.detailed,
          onTypeChanged: (type) {},
          enabled: false,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'summary_type_selector_states',
        scenarios: stateScenarios,
      );
    });

    testGoldens('SummaryTypeSelector - Multiple Devices', (tester) async {
      final widget = SummaryTypeSelector(
        selectedType: SummaryType.bulletPoints,
        onTypeChanged: (type) {},
        enabled: true,
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'summary_type_selector_devices',
        devices: GoldenTestHelpers.extendedTestDevices,
      );
    });

    testGoldens('SummaryTypeSelector - Light and Dark Themes', (tester) async {
      final widget = SummaryTypeSelector(
        selectedType: SummaryType.detailed,
        onTypeChanged: (type) {},
        enabled: true,
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'summary_type_selector_themes',
        testBothThemes: true,
      );
    });

    testGoldens('SummaryTypeSelector - Accessibility Testing', (tester) async {
      final widget = SummaryTypeSelector(
        selectedType: SummaryType.actionItems,
        onTypeChanged: (type) {},
        enabled: true,
      );

      await GoldenTestHelpers.testWidgetAccessibility(
        tester: tester,
        widget: widget,
        goldenFileName: 'summary_type_selector_accessibility',
        textScales: [0.8, 1.0, 1.2, 1.5, 2.0],
      );
    });

    testGoldens('SummaryTypeSelector - Interaction States', (tester) async {
      // Since we can't easily test actual interaction states in golden tests,
      // we'll test the visual appearance of different configurations
      final interactionScenarios = {
        'default_state': SummaryTypeSelector(
          selectedType: SummaryType.brief,
          onTypeChanged: (type) {},
          enabled: true,
        ),
        'disabled_interaction': SummaryTypeSelector(
          selectedType: SummaryType.brief,
          onTypeChanged: (type) {},
          enabled: false,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'summary_type_selector_interactions',
        scenarios: interactionScenarios,
      );
    });

    testGoldens('SummaryTypeSelector - All Types Showcase', (tester) async {
      // Create a showcase of all summary types for visual comparison
      final allTypesScenarios = <String, Widget>{};

      for (final type in SummaryType.values) {
        allTypesScenarios['type_${type.value}'] = SummaryTypeSelector(
          selectedType: type,
          onTypeChanged: (type) {},
          enabled: true,
        );
      }

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'summary_type_selector_all_types',
        scenarios: allTypesScenarios,
        devices: [
          GoldenTestHelpers.testDevices.first,
        ], // Use single device for showcase
      );
    });
  });
}
