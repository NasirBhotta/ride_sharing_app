from pathlib import Path


base = Path("lib/features/rides/presentation/customer")
path = base / "customer_home_page.dart"
text = path.read_text(encoding="utf-8")


def add_part(source: str, part_name: str) -> str:
    directive = f"part '{part_name}';\n"
    if directive in source:
        return source
    marker = "import '../widgets/vehicle_option_card.dart';\n\n"
    return source.replace(marker, marker + directive, 1)


def cut_between(source: str, start_marker: str, end_marker: str):
    start = source.index(start_marker)
    end = source.index(end_marker, start)
    return source[:start], source[start:end].strip() + "\n", source[end:]


parts = []

enum_start = text.index("enum _RouteState")
class_start = text.index("class CustomerHomePage")
route_state = text[enum_start:class_start].strip() + "\n"
text = text[:enum_start] + text[class_start:]
parts.append(("customer_home_page_route_state.dart", route_state))

before, location_body, after = cut_between(
    text,
    "  Future<void> _initLocation",
    "  Future<void> _updateRoute",
)
text = before + after
parts.append(
    (
        "customer_home_page_location.dart",
        "extension _CustomerHomePageLocation on _CustomerHomePageState {\n"
        + location_body
        + "}\n",
    )
)

before, route_body, after = cut_between(
    text,
    "  Future<void> _updateRoute",
    "  double _rad",
)
text = before + after
parts.append(
    (
        "customer_home_page_route.dart",
        "extension _CustomerHomePageRoute on _CustomerHomePageState {\n"
        + route_body
        + "}\n",
    )
)

before, actions_body, after = cut_between(
    text,
    "  double _rad",
    "  bool get _hasRide",
)
text = before + after
parts.append(
    (
        "customer_home_page_actions.dart",
        "extension _CustomerHomePageActions on _CustomerHomePageState {\n"
        + actions_body
        + "}\n",
    )
)

before, helpers_body, after = cut_between(
    text,
    "  bool get _hasRide",
    "  @override\n  Widget build",
)
text = before + after
parts.append(
    (
        "customer_home_page_ui_helpers.dart",
        "extension _CustomerHomePageUiHelpers on _CustomerHomePageState {\n"
        + helpers_body
        + "}\n",
    )
)

before, panels_body, after = cut_between(
    text,
    "  Widget _buildBottomPanelContent",
    "\n}\n",
)
text = before + "\n}" + after
parts.append(
    (
        "customer_home_page_panels.dart",
        "extension _CustomerHomePagePanels on _CustomerHomePageState {\n"
        + panels_body
        + "}\n",
    )
)

sheet_start = text.index("class DraggableGrowingSheet")
sheet_body = text[sheet_start:].strip() + "\n"
text = text[:sheet_start].rstrip() + "\n"
parts.append(("customer_home_page_widgets.dart", sheet_body))

for part_name, _ in parts:
    text = add_part(text, part_name)

path.write_text(text, encoding="utf-8")

for part_name, body in parts:
    (base / part_name).write_text(
        "part of 'customer_home_page.dart';\n\n" + body,
        encoding="utf-8",
    )
