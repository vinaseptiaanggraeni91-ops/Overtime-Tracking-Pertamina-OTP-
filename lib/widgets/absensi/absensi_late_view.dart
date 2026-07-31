// lib/screens/absensi/widgets/absensi_late_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/dashboard/mitra/absensi_state.dart';
import '/widgets/absensi/absensi_workflow.dart';
import '/widgets/absensi/shared/overtime_info_card.dart';

class AbsensiLateView extends StatelessWidget {
  final AbsensiState state;
  final AbsensiWorkflow workflow;

  const AbsensiLateView({
    super.key,
    required this.state,
    required this.workflow,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final hp = MediaQuery.of(context).size.width * 0.04;

    // Jika menampilkan daftar lembur terlambat (belum pilih spesifik)
    if (!state.isViewingLateOvertime || state.overtimeItem == null) {
      return _buildLateList(isSmall, hp);
    }

    // Jika sudah pilih lembur terlambat spesifik
    if (state.viewState == AbsensiViewState.lateForm) {
      return _buildKonfirmasiForm(isSmall, hp);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 24),
      child: Column(
        children: [
          OvertimeInfoCard(
            overtimeItem: state.overtimeItem!,
            isLateOvertime: true,
          ),
          const SizedBox(height: 16),
          _buildLateBanner(isSmall),
        ],
      ),
    );
  }

  Widget _buildLateList(bool isSmall, double hp) {
    if (state.lateOvertimeList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text('🎉 Tidak Ada Lembur Terlambat!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(hp),
      itemCount: state.lateOvertimeList.length,
      itemBuilder: (context, index) {
        final item = state.lateOvertimeList[index];
        return _LateOvertimeCard(
          item: item,
          isSmall: isSmall,
          onTap: () => workflow.selectLateOvertime(item),
        );
      },
    );
  }

  Widget _buildLateBanner(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade100, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: isSmall ? 20 : 24),
              const SizedBox(width: 8),
              Text(
                '⚠️ Anda Terlambat!',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: isSmall ? 14 : 16, color: Colors.orange.shade900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan konfirmasi apakah Anda tetap melakukan lembur atau tidak.\n(Maksimal 3 hari setelah jam selesai)',
            style: TextStyle(fontSize: isSmall ? 11 : 12, color: Colors.grey.shade800),
          ),
          if (state.errorDetail != null) ...[
            const SizedBox(height: 8),
            Text(state.errorDetail!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => workflow.showKonfirmasiForm(),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Konfirmasi Keterlambatan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKonfirmasiForm(bool isSmall, double hp) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 24),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 14 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 Form Konfirmasi Keterlambatan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: isSmall ? 14 : 16),
            ),
            const SizedBox(height: 16),
            
            // Apakah melakukan lembur?
            Text('Apakah Anda melakukan lembur?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _OptionCard(
                    title: '✅ Ya, Saya Lembur',
                    icon: Icons.work_history,
                    color: Colors.green,
                    selected: state.melakukanLembur == true,
                    onTap: () {
                      state.melakukanLembur = true;
                      state.notifyListeners();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OptionCard(
                    title: '❌ Tidak Lembur',
                    icon: Icons.cancel,
                    color: Colors.red,
                    selected: state.melakukanLembur == false,
                    onTap: () {
                      state.melakukanLembur = false;
                      state.notifyListeners();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Alasan
            Text('Alasan Keterlambatan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 14)),
            const SizedBox(height: 8),
            TextField(
              controller: state.alasanController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tulis alasan keterlambatan Anda...',
                border: OutlineInputBorder(),
              ),
            ),
            
            // Upload bukti foto jika memilih lembur
            if (state.melakukanLembur == true) ...[
              const SizedBox(height: 16),
              Text('📸 Foto Bukti Lembur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 14)),
              const SizedBox(height: 8),
              if (state.buktiFotoTerlambat != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(state.buktiFotoTerlambat!, height: 150, fit: BoxFit.cover),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => state.pickBuktiFoto(),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Ambil / Pilih Foto Bukti'),
                ),
            ],
            
            const SizedBox(height: 20),
            
            // Tombol submit & batal
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => workflow.hideKonfirmasiForm(),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: state.isSubmitting ? null : () => workflow.submitKonfirmasi(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                    child: state.isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Kirim Konfirmasi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LateOvertimeCard extends StatelessWidget {
  final dynamic item;
  final bool isSmall;
  final VoidCallback onTap;

  const _LateOvertimeCard({
    required this.item,
    required this.isSmall,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 10 : 12),
      padding: EdgeInsets.all(isSmall ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('dd MMM yyyy', 'id_ID').format(item.tanggal),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.jamMulai} - ${item.jamSelesai}',
                style: TextStyle(color: Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, foregroundColor: Colors.white),
              child: const Text('Konfirmasi Sekarang'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? color : Colors.grey.shade700,
              fontSize: 11,
            )),
          ],
        ),
      ),
    );
  }
}