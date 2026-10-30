// Port of frontend/src/components/ui/* — same variants, sizes, states and copy.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/* ================================ Buttons ================================ */

enum GwVariant { primary, secondary, ghost, subtle, danger }

enum GwSize { sm, md, lg }

class GwButton extends StatelessWidget {
  const GwButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = GwVariant.secondary,
    this.size = GwSize.md,
    this.loading = false,
    this.expand = false,
    this.trailingIcon,
  });

  /// Icon after the label (web: `Label <ArrowRight />`).
  final IconData? trailingIcon;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GwVariant variant;
  final GwSize size;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg, border, hover) = switch (variant) {
      GwVariant.primary => (Gw.violet, Gw.canvas, Colors.transparent, Gw.violetHover),
      GwVariant.secondary => (Gw.elevated, Gw.fg, Gw.line, Gw.hover),
      GwVariant.ghost => (Colors.transparent, Gw.fgSecondary, Colors.transparent, Gw.hover),
      GwVariant.subtle => (Gw.violetSoft, Gw.violet, Colors.transparent, const Color(0x2E8585FF)),
      GwVariant.danger => (Gw.danger, Gw.canvas, Colors.transparent, const Color(0xFFF47A82)),
    };
    final height = switch (size) { GwSize.sm => 32.0, GwSize.md => 40.0, GwSize.lg => 44.0 };
    final fontSize = switch (size) { GwSize.sm => 13.0, GwSize.md => 14.0, GwSize.lg => 15.0 };
    final weight = variant == GwVariant.primary || variant == GwVariant.danger ? FontWeight.w600 : FontWeight.w500;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg)))
        else if (icon != null)
          Padding(padding: EdgeInsets.only(right: label.isEmpty ? 0 : 8), child: Icon(icon, size: size == GwSize.sm ? 14 : 16, color: fg)),
        if (label.isNotEmpty) Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Gw.fontSans, fontSize: fontSize, fontWeight: weight, color: fg))),
        if (trailingIcon != null && !loading) Padding(padding: const EdgeInsets.only(left: 8), child: Icon(trailingIcon, size: size == GwSize.sm ? 14 : 16, color: fg)),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gw.rMd), side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          hoverColor: hover,
          highlightColor: hover,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 0 : (size == GwSize.lg ? 20 : (size == GwSize.sm ? 12 : 14))),
            width: label.isEmpty ? height : null,
            // Only fill the available width when asked to (web: w-full); otherwise hug the content.
            alignment: expand || label.isEmpty ? Alignment.center : null,
            child: expand ? child : Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

class GwIconButton extends StatelessWidget {
  const GwIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.size = 36, this.color = Gw.fgSecondary});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gw.rMd)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(dimension: size, child: Icon(icon, size: 18, color: onPressed == null ? Gw.fgDisabled : color)),
          ),
        ),
      );
}

class GwLink extends StatelessWidget {
  const GwLink(this.label, {super.key, required this.onTap, this.icon, this.style});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: style ?? GwText.meta.copyWith(color: Gw.violet, fontWeight: FontWeight.w500)),
            if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: 13, color: (style?.color) ?? Gw.violet)],
          ]),
        ),
      );
}

/* ================================ Form ================================ */

InputDecoration gwInputDecoration({String? hint, Widget? prefix, Widget? suffix, bool error = false, bool dense = false}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(Gw.rMd), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: GwText.body.copyWith(color: Gw.fgMuted),
    filled: true,
    fillColor: Gw.canvas,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 9 : 11),
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20),
    suffixIcon: suffix,
    border: b(error ? Gw.danger : Gw.line),
    enabledBorder: b(error ? Gw.danger : Gw.line),
    focusedBorder: b(error ? Gw.danger : Gw.violet, 1.5),
    disabledBorder: b(Gw.lineSubtle),
  );
}

/// Label + control + hint/error (web `Field`).
class GwField extends StatelessWidget {
  const GwField({super.key, required this.label, required this.child, this.hint, this.error, this.optional = false});
  final String label;
  final Widget child;
  final Widget? hint;
  final String? error;
  final bool optional;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: GwText.meta.copyWith(color: Gw.fgSecondary, fontWeight: FontWeight.w500))),
          if (optional) Text('Optional', style: GwText.micro),
        ]),
        const SizedBox(height: 6),
        child,
        if (error != null) ...[
          const SizedBox(height: 6),
          Semantics(liveRegion: true, child: Text(error!, style: GwText.meta.copyWith(color: Gw.danger))),
        ] else if (hint != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle(style: GwText.meta, child: hint!),
        ],
      ]);
}

class GwInput extends StatelessWidget {
  const GwInput({
    super.key,
    this.controller,
    this.hint,
    this.error = false,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.prefix,
    this.enabled = true,
    this.mono = false,
    this.maxLines = 1,
    this.minLines,
    this.initialValue,
    this.textInputAction,
    this.semanticLabel,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool error;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final Widget? prefix;
  final bool enabled;
  final bool mono;
  final int maxLines;
  final int? minLines;
  final String? initialValue;
  final TextInputAction? textInputAction;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        textField: true,
        label: semanticLabel,
        child: TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          obscureText: obscure,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          maxLines: obscure ? 1 : maxLines,
          minLines: minLines,
          textInputAction: textInputAction,
          style: mono ? GwText.mono.copyWith(fontSize: 13, color: Gw.fg) : GwText.body.copyWith(color: enabled ? Gw.fg : Gw.fgDisabled),
          decoration: gwInputDecoration(hint: hint, error: error, suffix: suffix, prefix: prefix),
        ),
      );
}

class GwSelect<T> extends StatelessWidget {
  const GwSelect({super.key, required this.value, required this.items, required this.onChanged, this.semanticLabel});
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: Gw.elevated,
          borderRadius: BorderRadius.circular(Gw.rLg),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Gw.fgSecondary),
          style: GwText.body,
          decoration: gwInputDecoration(dense: true),
          items: [for (final (v, label) in items) DropdownMenuItem(value: v, child: Text(label, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      );
}

class GwSearchField extends StatelessWidget {
  const GwSearchField({super.key, required this.controller, required this.hint, this.onChanged, this.onSubmitted});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => GwInput(
        controller: controller,
        hint: hint,
        semanticLabel: hint,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        prefix: const Icon(Icons.search, size: 16, color: Gw.fgMuted),
      );
}

/// Web `Switch`: label + description on the left, toggle on the right.
class GwSwitch extends StatelessWidget {
  const GwSwitch({super.key, required this.label, required this.value, required this.onChanged, this.description});
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GwText.bodyMedium),
              if (description != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(description!, style: GwText.meta)),
            ]),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            child: Semantics(
              toggled: value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 24,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: value ? Gw.violet : Gw.elevated,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: value ? Gw.violet : Gw.lineStrong),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 150),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(width: 18, height: 18, decoration: BoxDecoration(color: value ? Gw.canvas : Gw.fgSecondary, shape: BoxShape.circle)),
                ),
              ),
            ),
          ),
        ]),
      );
}

class GwSegmented<T> extends StatelessWidget {
  const GwSegmented({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Gw.canvas, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (v, label) in options)
            Semantics(
              selected: v == value,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: v == value ? Gw.elevated : Colors.transparent, borderRadius: BorderRadius.circular(5)),
                  child: Text(label, style: GwText.meta.copyWith(fontWeight: FontWeight.w500, color: v == value ? Gw.fg : Gw.fgMuted)),
                ),
              ),
            ),
        ]),
      );
}

class GwCheckbox extends StatelessWidget {
  const GwCheckbox({super.key, required this.value, required this.onChanged, required this.label, this.error = false});
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget label;
  final bool error;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(Gw.rMd),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: error ? Gw.danger.withValues(alpha: 0.6) : Gw.lineSubtle)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 32, height: 24, child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
            const SizedBox(width: 4),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: label)),
          ]),
        ),
      );
}

/* ================================ Layout ================================ */

class GwCard extends StatelessWidget {
  const GwCard({super.key, required this.child, this.padding, this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Gw.surface,
          borderRadius: BorderRadius.circular(Gw.rLg),
          border: Border.all(color: borderColor ?? Gw.line),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: child,
      );
}

class GwCardHeader extends StatelessWidget {
  const GwCardHeader({super.key, required this.title, this.description, this.action});
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: GwText.section)),
              if (description != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(description!, style: GwText.meta)),
            ]),
          ),
          ?action,
        ]),
      );
}

class GwPageHeader extends StatelessWidget {
  const GwPageHeader({super.key, required this.title, this.description, this.actions = const []});
  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: GwText.title)),
          if (description != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(description!, style: GwText.body.copyWith(color: Gw.fgMuted))),
          if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
        ]),
      );
}

class GwBackLink extends StatelessWidget {
  const GwBackLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: onTap,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.arrow_back, size: 14, color: Gw.fgMuted),
              const SizedBox(width: 6),
              Text(label, style: GwText.meta),
            ]),
          ),
        ),
      );
}

class GwKeyValue extends StatelessWidget {
  const GwKeyValue(this.label, this.value, {super.key, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(label, style: GwText.body.copyWith(color: Gw.fgMuted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: mono ? GwText.mono.copyWith(fontSize: 12.5) : GwText.body.copyWith(color: Gw.fgSecondary)),
          ),
        ]),
      );
}

class GwTabs<T> extends StatelessWidget {
  const GwTabs({super.key, required this.value, required this.tabs, required this.onChanged});
  final T value;
  final List<(T, String, IconData)> tabs;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (v, label, icon) in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                selected: v == value,
                button: true,
                child: Material(
                  color: v == value ? Gw.elevated : Colors.transparent,
                  borderRadius: BorderRadius.circular(Gw.rMd),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Gw.rMd),
                    onTap: () => onChanged(v),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        Icon(icon, size: 15, color: v == value ? Gw.fg : Gw.fgMuted),
                        const SizedBox(width: 8),
                        Text(label, style: GwText.bodyMedium.copyWith(color: v == value ? Gw.fg : Gw.fgMuted)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

class GwPagination extends StatelessWidget {
  const GwPagination({super.key, required this.page, required this.pageSize, required this.total, required this.onPage});
  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    final from = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final to = (page * pageSize).clamp(0, total);
    Widget arrow(IconData icon, String tip, bool enabled, int target) => Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.line)),
            child: GwIconButton(icon: icon, tooltip: tip, size: 32, onPressed: enabled ? () => onPage(target) : null),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Gw.lineSubtle))),
      child: Row(children: [
        Text('$from–$to of $total', style: GwText.meta),
        const Spacer(),
        arrow(Icons.chevron_left, 'Previous page', page > 1, page - 1),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('$page / $pages', style: GwText.meta.copyWith(color: Gw.fgSecondary))),
        arrow(Icons.chevron_right, 'Next page', page < pages, page + 1),
      ]),
    );
  }
}

/* ================================ Feedback ================================ */

class GwStatus {
  const GwStatus(this.label, this.color, this.bg, this.icon);
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;

  static GwStatus of(String status) => switch (status) {
        'succeeded' => const GwStatus('Succeeded', Gw.success, Gw.successSoft, Icons.check_circle_outline),
        'failed' => const GwStatus('Failed', Gw.danger, Gw.dangerSoft, Icons.highlight_off),
        'running' => const GwStatus('Running', Gw.cyan, Gw.cyanSoft, Icons.autorenew),
        'queued' => const GwStatus('Queued', Gw.queued, Gw.violetSoft, Icons.schedule),
        'cancelled' => const GwStatus('Cancelled', Gw.fgSecondary, Gw.elevated, Icons.block),
        'pending' => const GwStatus('Pending', Gw.fgMuted, Gw.elevated, Icons.radio_button_unchecked),
        'skipped' => const GwStatus('Skipped', Gw.fgMuted, Gw.elevated, Icons.skip_next_outlined),
        'active' => const GwStatus('Active', Gw.success, Gw.successSoft, Icons.radio_button_checked),
        'paused' => const GwStatus('Paused', Gw.warning, Gw.warningSoft, Icons.pause_circle_outline),
        'draft' => const GwStatus('Draft', Gw.fgSecondary, Gw.elevated, Icons.edit_note),
        'connected' => const GwStatus('Connected', Gw.success, Gw.successSoft, Icons.check_circle_outline),
        'error' => const GwStatus('Needs attention', Gw.danger, Gw.dangerSoft, Icons.warning_amber_rounded),
        _ => GwStatus(status, Gw.fgSecondary, Gw.elevated, Icons.info_outline),
      };
}

/// Status is never conveyed by color alone: icon + label + color (web StatusBadge).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.label, this.small = false});
  final String status;
  final String? label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final s = GwStatus.of(status);
    return Container(
      height: small ? 20 : 24,
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: small ? 11 : 12, color: s.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label ?? s.label,
              overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Gw.fontSans, fontSize: small ? 11 : 12, fontWeight: FontWeight.w500, color: s.color)),
        ),
      ]),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = GwStatus.of(status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(s.label, style: GwText.meta.copyWith(color: Gw.fgSecondary)),
    ]);
  }
}

enum AlertTone { danger, warning, info, success }

class GwAlert extends StatelessWidget {
  const GwAlert({super.key, required this.child, this.tone = AlertTone.danger});
  final Widget child;
  final AlertTone tone;

  @override
  Widget build(BuildContext context) {
    final (border, bg, text) = switch (tone) {
      AlertTone.danger => (Gw.danger, Gw.dangerSoft, Gw.dangerText),
      AlertTone.warning => (Gw.warning, Gw.warningSoft, Gw.warningText),
      AlertTone.info => (Gw.violet, Gw.violetSoft, Gw.infoText),
      AlertTone.success => (Gw.success, Gw.successSoft, Gw.successText),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: border.withValues(alpha: 0.3))),
        child: DefaultTextStyle(style: GwText.meta.copyWith(color: text), child: child),
      ),
    );
  }
}

class GwEmpty extends StatelessWidget {
  const GwEmpty({super.key, required this.title, this.icon, this.description, this.actions = const []});
  final String title;
  final IconData? icon;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null)
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Gw.elevated, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.line)),
              child: Icon(icon, size: 18, color: Gw.fgSecondary),
            ),
          Text(title, style: GwText.section, textAlign: TextAlign.center),
          if (description != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(description!, textAlign: TextAlign.center, style: GwText.body.copyWith(color: Gw.fgMuted))),
          if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 20), child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions)),
        ]),
      );
}

class GwError extends StatelessWidget {
  const GwError({super.key, this.title = 'Something went wrong', this.error, this.onRetry});
  final String title;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Gw.dangerSoft, borderRadius: BorderRadius.circular(Gw.rMd)),
            child: const Icon(Icons.warning_amber_rounded, size: 20, color: Gw.danger),
          ),
          Text(title, style: GwText.section, textAlign: TextAlign.center),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('$error', textAlign: TextAlign.center, style: GwText.body.copyWith(color: Gw.fgMuted))),
          if (onRetry != null) Padding(padding: const EdgeInsets.only(top: 16), child: GwButton(label: 'Try again', icon: Icons.refresh, size: GwSize.sm, onPressed: onRetry)),
        ]),
      );
}

class GwSkeleton extends StatefulWidget {
  const GwSkeleton({super.key, this.height = 40, this.width});
  final double height;
  final double? width;

  @override
  State<GwSkeleton> createState() => _GwSkeletonState();
}

class _GwSkeletonState extends State<GwSkeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return FadeTransition(
      opacity: reduce ? const AlwaysStoppedAnimation(0.7) : Tween(begin: 0.5, end: 1.0).animate(_c),
      child: Container(height: widget.height, width: widget.width, decoration: BoxDecoration(color: Gw.elevated, borderRadius: BorderRadius.circular(Gw.rMd))),
    );
  }
}

class GwLoading extends StatelessWidget {
  const GwLoading({super.key, this.rows = 3, this.label = 'Loading'});
  final int rows;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (var i = 0; i < rows; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FractionallySizedBox(widthFactor: i == rows - 1 ? 0.66 : 1, alignment: Alignment.centerLeft, child: const GwSkeleton()),
              ),
          ]),
        ),
      );
}

/* ================================ Overlays ================================ */

/// Modal dialog with the web's header / body / footer layout.
Future<T?> showGwDialog<T>(
  BuildContext context, {
  required String title,
  String? description,
  required Widget Function(BuildContext) body,
  List<Widget> Function(BuildContext)? footer,
}) =>
    showDialog<T>(
      context: context,
      barrierColor: const Color(0xB8050609),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: GwText.section),
                    if (description != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(description, style: GwText.body.copyWith(color: Gw.fgMuted))),
                  ]),
                ),
                GwIconButton(icon: Icons.close, tooltip: 'Close', size: 32, onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: body(ctx))),
            if (footer != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(color: Color(0x9910131A), border: Border(top: BorderSide(color: Gw.lineSubtle))),
                child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: footer(ctx)),
              ),
          ]),
        ),
      ),
    );

/// Confirm dialog (web ConfirmDialog). `action` runs while the dialog shows a loading state;
/// returning a string keeps the dialog open and shows it as an error.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String description,
  required String confirmLabel,
  bool danger = false,
  Future<String?> Function()? action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB8050609),
    builder: (ctx) => _ConfirmDialog(title: title, description: description, confirmLabel: confirmLabel, danger: danger, action: action),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.title, required this.description, required this.confirmLabel, required this.danger, this.action});
  final String title;
  final String description;
  final String confirmLabel;
  final bool danger;
  final Future<String?> Function()? action;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
              child: Row(children: [
                Expanded(child: Text(widget.title, style: GwText.section)),
                GwIconButton(icon: Icons.close, tooltip: 'Close', size: 32, onPressed: _busy ? null : () => Navigator.pop(context, false)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(widget.description, style: GwText.body.copyWith(color: Gw.fgSecondary)),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: GwAlert(child: Text(_error!))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(color: Color(0x9910131A), border: Border(top: BorderSide(color: Gw.lineSubtle))),
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                GwButton(label: 'Cancel', onPressed: _busy ? null : () => Navigator.pop(context, false)),
                GwButton(
                  label: widget.confirmLabel,
                  variant: widget.danger ? GwVariant.danger : GwVariant.primary,
                  loading: _busy,
                  onPressed: () async {
                    if (widget.action == null) return Navigator.pop(context, true);
                    setState(() => (_busy = true, _error = null));
                    final error = await widget.action!();
                    if (!context.mounted) return;
                    if (error == null) {
                      Navigator.pop(context, true);
                    } else {
                      setState(() => (_busy = false, _error = error));
                    }
                  },
                ),
              ]),
            ),
          ]),
        ),
      );
}

/// Side sheet (web Drawer): slides in from the left or right.
Future<T?> showSideSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder, bool left = false, double width = 352}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0xB8050609),
      transitionDuration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => Align(
        alignment: left ? Alignment.centerLeft : Alignment.centerRight,
        child: Material(
          color: Gw.sidebar,
          child: SizedBox(
            width: width.clamp(0, MediaQuery.of(ctx).size.width - 40).toDouble(),
            height: double.infinity,
            child: SafeArea(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
                  child: Row(children: [
                    Expanded(child: Text(title, style: GwText.section)),
                    GwIconButton(icon: Icons.close, tooltip: 'Close', size: 32, onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),
                Expanded(child: builder(ctx)),
              ]),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween(begin: Offset(left ? -0.08 : 0.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: const Cubic(0.22, 1, 0.36, 1))),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );

/// Toast (web useToast): success / error / info.
void toast(BuildContext context, String title, {String? description, AlertTone tone = AlertTone.success}) {
  final (icon, color) = switch (tone) {
    AlertTone.success => (Icons.check_circle_outline, Gw.success),
    AlertTone.danger => (Icons.highlight_off, Gw.danger),
    _ => (Icons.info_outline, Gw.violet),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: Duration(milliseconds: tone == AlertTone.danger ? 8000 : 4500),
      content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: GwText.bodyMedium),
            if (description != null) Text(description, style: GwText.meta),
          ]),
        ),
      ]),
    ));
}

/// Read-only value with a copy button (web CopyField).
class GwCopyField extends StatefulWidget {
  const GwCopyField({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  State<GwCopyField> createState() => _GwCopyFieldState();
}

class _GwCopyFieldState extends State<GwCopyField> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12, right: 2),
        decoration: BoxDecoration(color: Gw.canvas, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.line)),
        child: Row(children: [
          Expanded(child: Text(widget.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GwText.mono.copyWith(fontSize: 12.5))),
          GwIconButton(
            icon: _copied ? Icons.check : Icons.copy,
            color: _copied ? Gw.success : Gw.fgSecondary,
            tooltip: _copied ? 'Copied' : 'Copy ${widget.label}',
            size: 32,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.value));
              setState(() => _copied = true);
              Future.delayed(const Duration(milliseconds: 1500), () => mounted ? setState(() => _copied = false) : null);
            },
          ),
        ]),
      );
}

class GwCopyChip extends StatefulWidget {
  const GwCopyChip(this.text, {super.key});
  final String text;

  @override
  State<GwCopyChip> createState() => _GwCopyChipState();
}

class _GwCopyChipState extends State<GwCopyChip> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: widget.text));
          setState(() => _copied = true);
          Future.delayed(const Duration(milliseconds: 1200), () => mounted ? setState(() => _copied = false) : null);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: Gw.canvas, borderRadius: BorderRadius.circular(4), border: Border.all(color: Gw.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(widget.text, overflow: TextOverflow.ellipsis, style: GwText.mono.copyWith(fontSize: 11))),
            const SizedBox(width: 4),
            Icon(_copied ? Icons.check : Icons.copy, size: 11, color: _copied ? Gw.success : Gw.fgSecondary),
          ]),
        ),
      );
}
