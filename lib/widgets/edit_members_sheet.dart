import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/trip_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

const _uuid = Uuid();

class EditMembersSheet extends StatefulWidget {
  final List<Member> allMembers;
  final List<Expense> expenses;

  const EditMembersSheet({
    super.key,
    required this.allMembers,
    required this.expenses,
  });

  @override
  State<EditMembersSheet> createState() => _EditMembersSheetState();
}

class _EditMembersSheetState extends State<EditMembersSheet> {
  late List<Member> _members;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.allMembers);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Member> get _active => _members.where((m) => m.active).toList();

  int _activityCount(Member member) => widget.expenses
      .where((e) => e.payer == member.id || (e.splits[member.id] ?? 0) > 0)
      .length;

  void _saveToProvider() =>
      context.read<TripProvider>().setTripMembers(List.from(_members));

  void _add(AppStrings s) {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    if (_active.any((m) => m.name.toLowerCase() == name.toLowerCase())) {
      _err(s.errorDuplicateMember);
      return;
    }
    setState(() {
      _members.add(Member(
        id: _uuid.v4(),
        name: name,
        colorIndex: AppTheme.memberColorOrder[_members.length % AppTheme.memberColorOrder.length],
      ));
      _ctrl.clear();
    });
    _saveToProvider();
  }

  void _rename(Member member, String newName, AppStrings s) {
    if (newName.isEmpty || newName == member.name) return;
    if (_active.any((m) => m.id != member.id && m.name.toLowerCase() == newName.toLowerCase())) {
      _err(s.errorDuplicateMember);
      return;
    }
    setState(() {
      final idx = _members.indexWhere((m) => m.id == member.id);
      if (idx != -1) _members[idx] = _members[idx].copyWith(name: newName);
    });
    _saveToProvider();
  }

  void _requestRemove(Member member, AppStrings s) {
    if (_active.length <= 2) {
      _err(s.errorMinMembers);
      return;
    }
    final count = _activityCount(member);
    if (count > 0) {
      _showRemoveConfirm(member, count, s);
    } else {
      _softRemove(member);
    }
  }

  void _softRemove(Member member) {
    setState(() {
      final idx = _members.indexWhere((m) => m.id == member.id);
      if (idx != -1) _members[idx] = _members[idx].copyWith(active: false);
    });
    _saveToProvider();
  }

  void _showRemoveConfirm(Member member, int count, AppStrings s) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
        title: Text(
          s.removeMember,
          style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.memberHasExpenses(member.name, count),
              style: GoogleFonts.inter(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.amberFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(FluentIcons.warning_24_regular, size: 16, color: AppTheme.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.removeMemberWarning,
                      style: GoogleFonts.inter(color: AppTheme.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _softRemove(member);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            child: Text(s.eliminate),
          ),
        ],
      ),
    );
  }

  void _changeColor(Member member, int colorIndex) {
    setState(() {
      final idx = _members.indexWhere((m) => m.id == member.id);
      if (idx != -1) _members[idx] = _members[idx].copyWith(colorIndex: colorIndex);
    });
    _saveToProvider();
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppTheme.red),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final activeMembers = _active;

    return Container(
      height: mq.size.height * 0.85,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  s.editMembers,
                  style: GoogleFonts.inter(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: c.surfaceHigher, shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 16, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, mq.viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(s.currentParticipantCount(activeMembers.length), c),
                  const SizedBox(height: 8),
                  ...activeMembers.map((m) => _MemberRow(
                    key: ValueKey(m.id),
                    member: m,
                    activityCount: _activityCount(m),
                    allActiveNames: activeMembers.map((m) => m.name).toList(),
                    canRemove: true,
                    onRemove: () => _requestRemove(m, s),
                    onRename: (newName) => _rename(m, newName, s),
                    onColorChange: (idx) => _changeColor(m, idx),
                    strings: s,
                  )),
                  const SizedBox(height: 24),

                  _label(s.addParticipant, c),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          style: GoogleFonts.inter(color: c.textPrimary, fontSize: 15),
                          decoration: InputDecoration(hintText: s.memberNameHint),
                          onSubmitted: (_) => _add(s),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _add(s),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: const Icon(Icons.add, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t, AppColors c) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      t,
      style: GoogleFonts.inter(
        color: c.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ── Member Row ────────────────────────────────────────
class _MemberRow extends StatefulWidget {
  final Member member;
  final int activityCount;
  final List<String> allActiveNames;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onColorChange;
  final AppStrings strings;

  const _MemberRow({
    super.key,
    required this.member,
    required this.activityCount,
    required this.allActiveNames,
    required this.canRemove,
    required this.onRemove,
    required this.onRename,
    required this.onColorChange,
    required this.strings,
  });

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _editing = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.member.name);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  void _confirmRename() {
    final name = _editCtrl.text.trim();
    setState(() => _editing = false);
    if (name.isNotEmpty && name != widget.member.name) {
      widget.onRename(name);
    }
  }

  void _cancelEdit() {
    _editCtrl.text = widget.member.name;
    setState(() => _editing = false);
  }

  void _showColorPicker(BuildContext context) {
    final current = widget.member.colorIndex
        ?? widget.allActiveNames.indexOf(widget.member.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPickerSheet(
        current: current < 0 ? 0 : current,
        onChange: (idx) {
          Navigator.pop(context);
          widget.onColorChange(idx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final s = widget.strings;

    if (_editing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            MemberAvatar(name: widget.member.name, allMembers: widget.allActiveNames, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _editCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: accent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                onSubmitted: (_) => _confirmRename(),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _confirmRename,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.accentFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.check, size: 16, color: accent),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _cancelEdit,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.surfaceHigher, shape: BoxShape.circle),
                child: Icon(Icons.close, size: 14, color: c.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Delete button — left side
          GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.redFill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.delete_outline, size: 16, color: AppTheme.red),
            ),
          ),
          const SizedBox(width: 6),
          // Edit button — left side
          GestureDetector(
            onTap: () => setState(() => _editing = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: c.surfaceHigher,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.edit_outlined, size: 16, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showColorPicker(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                MemberAvatar(name: widget.member.name, allMembers: widget.allActiveNames, size: 36),
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: c.surfaceHigher,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border, width: 1),
                    ),
                    child: Icon(Icons.color_lens_outlined, size: 8, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.member.name,
                  style: GoogleFonts.inter(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.activityCount > 0)
                  Text(
                    s.memberActivityCount(widget.activityCount),
                    style: GoogleFonts.inter(color: AppTheme.amber, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Color Picker Sheet ────────────────────────────────
class _ColorPickerSheet extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChange;

  const _ColorPickerSheet({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final palette = AppTheme.avatarPalette;
    final normalized = current % palette.length;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.memberColorTitle,
            style: GoogleFonts.inter(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(palette.length, (i) {
              final bg = palette[i][0];
              final accent = palette[i][1];
              final selected = i == normalized;
              return GestureDetector(
                onTap: () => onChange(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? accent : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded, color: accent, size: 20)
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
