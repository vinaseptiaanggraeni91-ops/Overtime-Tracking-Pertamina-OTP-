// lib/widgets/pending_summary.dart
import 'package:flutter/material.dart';

class PendingSummary extends StatelessWidget {
  final List<Map<String, dynamic>> pendingList;
  final String Function(dynamic) getTimeAgo;
  final Future<void> Function(String id, bool approve, String note) onApprove;

  const PendingSummary({
    super.key,
    required this.pendingList,
    required this.getTimeAgo,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Menunggu Persetujuan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${pendingList.length} pending',
                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 40, color: Colors.green),
                    SizedBox(height: 8),
                    Text('Tidak ada pengajuan pending', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...pendingList.take(5).map((item) => _buildItem(context, item)),
          if (pendingList.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/approval'),
                  child: Text('Lihat ${pendingList.length - 5} lainnya...'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(51)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.work_history, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['pengawas_nama'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${(item['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam - ${item['alasan'] ?? '-'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(getTimeAgo(item['created_at']),
                    style: TextStyle(fontSize: 9, color: Colors.grey[400])),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.check, Colors.green, () => onApprove(item['id'], true, 'Disetujui')),
              const SizedBox(width: 6),
              _buildActionButton(Icons.close, Colors.red, () => onApprove(item['id'], false, 'Ditolak')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}