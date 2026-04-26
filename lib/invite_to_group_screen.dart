import 'package:flutter/material.dart';

import 'community_service.dart';

class InviteToGroupScreen extends StatefulWidget {
  const InviteToGroupScreen({
    super.key,
    required this.inviteId,
    required this.inviteToken,
  });

  final String inviteId;
  final String inviteToken;

  @override
  State<InviteToGroupScreen> createState() => _InviteToGroupScreenState();
}

class _InviteToGroupScreenState extends State<InviteToGroupScreen> {
  CommunityInviteDetails? _details;
  bool _loading = true;
  bool _accepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final details = await CommunityService.instance.fetchInviteDetails(
        inviteId: widget.inviteId,
        token: widget.inviteToken,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } on CommunityServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $error';
        _loading = false;
      });
    }
  }

  Future<void> _acceptInvite() async {
    if (_accepting) return;

    setState(() {
      _accepting = true;
      _error = null;
    });

    try {
      await CommunityService.instance.acceptInvite(
        inviteId: widget.inviteId,
        token: widget.inviteToken,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You joined the community group successfully'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pop();
    } on CommunityServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _accepting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $error';
        _accepting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            colors: [Color(0xFF1D4ED8), Color(0xFF4338CA), Color(0xFF7C3AED)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _loading
                      ? 'Loading Invitation'
                      : details != null
                      ? 'Join ${details.groupName}'
                      : 'Invitation Unavailable',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _loading
                      ? 'We are checking your Carebit invite.'
                      : details != null
                      ? '${details.inviterName} invited ${details.invitedEmail} to join this Carebit community group.'
                      : 'We could not load this invite.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.white.withOpacity(0.72),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow(
                              'Community group',
                              details?.groupName ?? '--',
                            ),
                            const SizedBox(height: 10),
                            _detailRow(
                              'Invited account',
                              details?.invitedEmail ?? '--',
                            ),
                            const SizedBox(height: 10),
                            _detailRow(
                              'Expires',
                              details != null
                                  ? _formatExpiry(details.expiresAt)
                                  : '--',
                            ),
                          ],
                        ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2).withOpacity(0.94),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 12.5,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading || details == null || _accepting
                        ? null
                        : _acceptInvite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4338CA),
                      disabledBackgroundColor: Colors.white.withOpacity(0.55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _accepting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text(
                            'Accept Invitation',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'You must be signed in with the invited Carebit account to accept this invite.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.58),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.62),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatExpiry(DateTime value) {
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][value.month - 1];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$month ${value.day}, ${value.year} at $hour:$minute $period';
  }
}
