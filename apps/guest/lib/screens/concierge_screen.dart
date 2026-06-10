import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/guest_api_service.dart';
import '../services/auth_service.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  String content;
  bool streaming;
  Map<String, dynamic>? intent; // parsed action intent, if any

  ChatMessage({required this.role, this.content = '', this.streaming = false, this.intent});
}

class ConciergeScreen extends StatefulWidget {
  final String tenantId;
  final String hotelName;

  const ConciergeScreen({super.key, required this.tenantId, required this.hotelName});

  @override
  State<ConciergeScreen> createState() => _ConciergeScreenState();
}

class _ConciergeScreenState extends State<ConciergeScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;

  // Quick-reply chips — updated dynamically after each assistant response
  List<String> _chips = [
    'What time does the pool close?',
    'Order me a club sandwich to room 204',
    'Book me a table for 2 at 7pm',
    'What amenities are available?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Strip ```json...``` block from text and return (displayText, intent?).
  (String, Map<String, dynamic>?) _parseIntent(String text) {
    final re = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final m = re.firstMatch(text);
    if (m == null) return (text, null);
    try {
      final intent = jsonDecode(m.group(1)!) as Map<String, dynamic>;
      final display = text.replaceAll(m.group(0)!, '').trim();
      return (display, intent);
    } catch (_) {
      return (text, null);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;
    _ctrl.clear();

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text.trim()));
      _messages.add(ChatMessage(role: 'assistant', content: '', streaming: true));
      _sending = true;
    });
    _scrollToBottom();

    try {
      // Build message list — spec: last 20 messages sent with each request
      final all = _messages
          .where((m) => !(m.role == 'assistant' && m.streaming && m.content.isEmpty))
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      final apiMessages = all.length > 20 ? all.sublist(all.length - 20) : all;

      // Attach auth token so server can personalise with guest name + reservation
      final token = await AuthService.getToken();

      final request = http.Request(
        'POST',
        Uri.parse('${GuestApiService.baseUrl}/ai/concierge'),
      );
      request.headers['Content-Type'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.body = jsonEncode({'messages': apiMessages, 'tenantId': widget.tenantId});

      final streamedResponse = await request.send();
      String buffer = '';

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          try {
            final event = jsonDecode(line.substring(6));
            if (event['type'] == 'text') {
              setState(() => _messages.last.content += event['text'] as String);
              _scrollToBottom();
            }
            if (event['type'] == 'error') {
              setState(() {
                _messages.last.content = '⚠️ ${event['message']}';
                _messages.last.streaming = false;
              });
            }
          } catch (_) {}
        }
      }

      // Parse intent block from completed response
      final raw = _messages.last.content;
      final (display, intent) = _parseIntent(raw);

      setState(() {
        _messages.last.content =
            display.isEmpty && intent != null ? 'I have prepared your request:' : display;
        _messages.last.intent = intent;
        _messages.last.streaming = false;
        _sending = false;
        _updateChips(display);
      });
    } catch (e) {
      setState(() {
        _messages.last.content = '⚠️ Could not connect to the concierge. Please try again.';
        _messages.last.streaming = false;
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  // Derive contextual chips from the latest assistant response
  void _updateChips(String reply) {
    final lower = reply.toLowerCase();
    if (lower.contains('order') || lower.contains('menu') || lower.contains('food') || lower.contains('sandwich')) {
      _chips = ['Show me the drinks menu', "What's today's special?", 'Order room service', 'View full menu'];
    } else if (lower.contains('pool') || lower.contains('gym') || lower.contains('spa') || lower.contains('ameniti')) {
      _chips = ['Book a spa treatment', 'What time is breakfast?', 'Gym equipment available?', 'Is the pool heated?'];
    } else if (lower.contains('check') || lower.contains('room') || lower.contains('key') || lower.contains('reserv')) {
      _chips = ['View my bill', 'Request housekeeping', 'Need an extra towel', 'Late checkout available?'];
    } else if (lower.contains('table') || lower.contains('reserv') || lower.contains('dinner')) {
      _chips = ['Book a table for 2', 'Order drinks to the table', 'View restaurant hours', 'What\'s on the menu?'];
    } else {
      _chips = ['Order food to my room', 'What time does the pool close?', "What's on the menu?", 'Need assistance'];
    }
  }

  // ─── Intent execution ─────────────────────────────────────────────────────────

  Future<void> _executeIntent(Map<String, dynamic> intent) async {
    final type = intent['intent'] as String?;
    if (type == 'place_order') {
      await _showOrderSheet(intent);
    } else if (type == 'book_table') {
      _showTableDialog(intent);
    }
  }

  Future<void> _showOrderSheet(Map<String, dynamic> intent) async {
    final rawItems = (intent['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final room = (intent['room'] ?? intent['roomNumber']) as String?;
    final isRoomService = (intent['isRoomService'] as bool?) ?? room != null;

    bool placing = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const Text('Confirm Order',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
            const SizedBox(height: 4),
            const Text('Review your AI-assisted order',
                style: TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
            const SizedBox(height: 16),
            // Items list
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                ...rawItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(item['name'] as String? ?? '—',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1E2A3A))),
                    Text('×${item['qty'] ?? 1}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF888EA8))),
                  ]),
                )),
                if (room != null) ...[
                  const Divider(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Deliver to', style: TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
                    Text(isRoomService ? 'Room $room' : 'Table',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: placing ? null : () async {
                setS(() => placing = true);
                try {
                  // Resolve item names → menuItemIds
                  final menuItems = await GuestApiService.getMenu(widget.tenantId);
                  final drinks    = await GuestApiService.getDrinks(widget.tenantId);
                  final all       = [...menuItems, ...drinks].cast<Map<String, dynamic>>();

                  final orderItems = <Map<String, dynamic>>[];
                  for (final intentItem in rawItems) {
                    final name  = (intentItem['name'] as String? ?? '').toLowerCase();
                    final found = all.where(
                      (m) => (m['name'] as String).toLowerCase().contains(name),
                    ).firstOrNull;
                    if (found != null) {
                      orderItems.add({'menuItemId': found['id'] as String, 'qty': intentItem['qty'] ?? 1});
                    }
                  }

                  if (orderItems.isEmpty) {
                    throw Exception('Could not match these items to the menu. Please order from the Menu tab directly.');
                  }

                  final orderPayload = <String, dynamic>{
                    'isRoomService': isRoomService,
                    'items': orderItems,
                  };
                  if (room != null) orderPayload['roomNumber'] = room;
                  await GuestApiService.placeOrder(widget.tenantId, orderPayload);

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Order placed! We will prepare it shortly.'),
                      backgroundColor: Color(0xFF4CAF50),
                      behavior: SnackBarBehavior.floating,
                    ));
                    setState(() => _messages.add(ChatMessage(
                        role: 'assistant',
                        content: 'Your order has been placed. You will receive a notification when it is ready.')));
                    _scrollToBottom();
                  }
                } catch (e) {
                  setS(() => placing = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              },
              child: placing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm & Place Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF888EA8))),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showTableDialog(Map<String, dynamic> intent) {
    final partySize = intent['partySize'] ?? 2;
    final time = intent['time'] as String? ?? '';
    final notes = intent['notes'] as String? ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Table Request Sent'),
        content: Text(
          'Table for $partySize at $time${notes.isNotEmpty ? " — $notes" : ""}.\nA staff member will confirm your reservation shortly.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    setState(() => _messages.add(ChatMessage(
        role: 'assistant',
        content: 'Your table request for $partySize guests at $time has been noted. A staff member will confirm your reservation shortly.')));
    _scrollToBottom();
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI Concierge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(widget.hotelName, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(children: [
              Icon(Icons.circle, size: 8, color: Color(0xFF4CAF50)),
              SizedBox(width: 4),
              Text('Claude', style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50))),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        // Messages or empty state
        Expanded(
          child: _messages.isEmpty
              ? _emptyState()
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
                ),
        ),
        // Contextual quick-reply chips — shown after the first exchange
        if (!_sending && _messages.isNotEmpty) _buildChipRow(),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildChipRow() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
          child: ActionChip(
            label: Text(_chips[i],
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E2A3A))),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE0E0E0)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => _sendMessage(_chips[i]),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 32),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: const Color(0xFF1E2A3A), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.smart_toy_outlined, size: 36, color: Color(0xFF4CAF50)),
        ),
        const SizedBox(height: 16),
        const Text('How can I help you?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
        const SizedBox(height: 6),
        const Text('Ask me anything about the hotel,\nfood, drinks, or services.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF888EA8), height: 1.5)),
        const SizedBox(height: 28),
        Wrap(
          spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
          children: _chips.map((s) => GestureDetector(
            onTap: () => _sendMessage(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text(s, style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A))),
            ),
          )).toList(),
        ),
      ]),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1E2A3A),
                  child: const Icon(Icons.smart_toy_outlined, size: 18, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF1E2A3A) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: msg.streaming && msg.content.isEmpty
                      ? _typingIndicator()
                      : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Flexible(child: Text(
                            msg.content.isEmpty ? '…' : msg.content,
                            style: TextStyle(
                                fontSize: 14,
                                color: isUser ? Colors.white : const Color(0xFF1E2A3A),
                                height: 1.45),
                          )),
                          if (msg.streaming && msg.content.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 4, bottom: 2),
                              width: 6, height: 14,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF888EA8), borderRadius: BorderRadius.circular(2)),
                            ),
                        ]),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
          // Action intent card — shown below assistant bubble when an intent is detected
          if (!isUser && msg.intent != null && !msg.streaming)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8, bottom: 6),
              child: _buildIntentCard(msg.intent!),
            ),
        ],
      ),
    );
  }

  Widget _buildIntentCard(Map<String, dynamic> intent) {
    final type = intent['intent'] as String?;
    final isOrder = type == 'place_order';
    final color = isOrder ? const Color(0xFF4CAF50) : const Color(0xFF2196F3);
    final icon  = isOrder ? Icons.restaurant : Icons.table_restaurant;
    final items = isOrder ? (intent['items'] as List?)?.cast<Map<String, dynamic>>() ?? [] : <Map<String, dynamic>>[];
    final partySize = intent['partySize'];
    final time = intent['time'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(isOrder ? 'Order Ready to Place' : 'Table Request',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 8),
        if (isOrder)
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text('• ${item['name']} ×${item['qty'] ?? 1}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A))),
          ))
        else
          Text('$partySize guests at $time',
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A))),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _executeIntent(intent),
            child: Text(isOrder ? 'Place Order' : 'Confirm Request'),
          ),
        ),
      ]),
    );
  }

  Widget _typingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Container(
        margin: EdgeInsets.only(right: i < 2 ? 4.0 : 0),
        width: 7, height: 7,
        decoration: const BoxDecoration(color: Color(0xFF888EA8), shape: BoxShape.circle),
      )),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            enabled: !_sending,
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: _sendMessage,
            decoration: InputDecoration(
              hintText: 'Ask the concierge…',
              hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
              filled: true, fillColor: const Color(0xFFF5F6FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sending ? null : () => _sendMessage(_ctrl.text),
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _sending ? const Color(0xFFE0E0E0) : const Color(0xFF1E2A3A),
              shape: BoxShape.circle,
            ),
            child: _sending
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
