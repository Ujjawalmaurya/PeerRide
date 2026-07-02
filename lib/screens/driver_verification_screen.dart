import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class DriverVerificationScreen extends ConsumerStatefulWidget {
  const DriverVerificationScreen({super.key});

  @override
  ConsumerState<DriverVerificationScreen> createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends ConsumerState<DriverVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleController = TextEditingController();
  
  bool _loading = false;
  String? _message;
  String? _error;

  // Mock files state
  String? _aadhaarFileName;
  List<int>? _aadhaarBytes;
  String? _rcFileName;
  List<int>? _rcBytes;
  String? _permitFileName;
  List<int>? _permitBytes;

  @override
  void dispose() {
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      setState(() => _error = 'Failed to refresh verification status: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startDigiLockerAadhaar() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('verification/digilocker/auth');
      final authUrl = response.data['authUrl'] as String?;

      if (authUrl != null && authUrl.isNotEmpty) {
        log.i('[VERIFICATION] Launching DigiLocker auth URL: $authUrl');
        await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
        setState(() {
          _message = 'DigiLocker window opened. Please complete authentication and refresh this screen.';
        });
      } else {
        setState(() => _error = 'Invalid authentication URL returned from server.');
      }
    } catch (e) {
      setState(() => _error = 'DigiLocker OAuth request failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyVahanRC() async {
    if (_vehicleController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a valid vehicle registration number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('verification/rc', data: {
        'vehicleNumber': _vehicleController.text.trim().toUpperCase(),
      });
      setState(() {
        _message = response.data['message'] ?? 'Vehicle RC verified successfully!';
      });
      // Refresh profile to reflect any verification status updates
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      setState(() => _error = 'Vehicle RC verification failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Pick mock files (simulating local document uploads)
  void _pickMockFile(String fileType) {
    setState(() {
      final dummyBytes = List<int>.generate(100, (i) => i);
      if (fileType == 'aadhaar') {
        _aadhaarFileName = 'aadhaar_card_proof.pdf';
        _aadhaarBytes = dummyBytes;
      } else if (fileType == 'rc') {
        _rcFileName = 'vehicle_registration.pdf';
        _rcBytes = dummyBytes;
      } else if (fileType == 'permit') {
        _permitFileName = 'ambulance_permit.pdf';
        _permitBytes = dummyBytes;
      }
    });
  }

  Future<void> _submitDocuments() async {
    if (_aadhaarBytes == null || _rcBytes == null || _permitBytes == null) {
      setState(() => _error = 'Please select all three documents (Aadhaar, Vehicle RC, and Permit).');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final dio = ref.read(dioProvider);
      
      // Construct FormData for multipart upload
      final formData = FormData.fromMap({
        'aadhaar': MultipartFile.fromBytes(
          _aadhaarBytes!,
          filename: _aadhaarFileName,
        ),
        'vehicleReg': MultipartFile.fromBytes(
          _rcBytes!,
          filename: _rcFileName,
        ),
        'ambulancePermit': MultipartFile.fromBytes(
          _permitBytes!,
          filename: _permitFileName,
        ),
      });

      final response = await dio.post('verification/submit', data: formData);
      setState(() {
        _message = response.data['message'] ?? 'Documents submitted successfully!';
      });
      
      // Refresh profile to update UI status to pending
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      setState(() => _error = 'Document submission failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.value?.user;
    final status = user?.verificationStatus ?? 'none';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Verification Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusBanner(status),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (_message != null)
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(_message!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  if (status == 'none' || status == 'rejected') ...[
                    _buildDigiLockerSection(),
                    const SizedBox(height: 24),
                    _buildDocumentsUploadSection(),
                  ] else if (status == 'pending') ...[
                    _buildPendingDetailCard(),
                  ] else if (status == 'approved') ...[
                    _buildApprovedCard(),
                  ]
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBanner(String status) {
    Color bannerColor;
    IconData icon;
    String statusTitle;
    String statusDesc;

    switch (status) {
      case 'approved':
        bannerColor = Colors.green;
        icon = Icons.verified_user;
        statusTitle = 'VERIFICATION APPROVED';
        statusDesc = 'You are verified and fully authorized to accept emergency rides.';
        break;
      case 'pending':
        bannerColor = Colors.amber.shade800;
        icon = Icons.pending_actions;
        statusTitle = 'REVIEW IN PROGRESS';
        statusDesc = 'Your verification request has been submitted. Admins are reviewing your credentials.';
        break;
      case 'rejected':
        bannerColor = Colors.red;
        icon = Icons.gpp_bad;
        statusTitle = 'VERIFICATION REJECTED';
        statusDesc = 'Review rejected. Please check requirements and re-submit your verification documents.';
        break;
      default:
        bannerColor = Colors.blueGrey;
        icon = Icons.shield;
        statusTitle = 'UNVERIFIED PROFILE';
        statusDesc = 'Please complete DigiLocker or manual document uploads to start receiving emergency bookings.';
    }

    return Container(
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDesc,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigiLockerSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'DigiLocker Verification (Recommended)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Instantly verify your identities through DigiLocker OAuth for faster, automated activation.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onPressed: _startDigiLockerAadhaar,
              icon: const Icon(Icons.security),
              label: const Text('Verify Aadhaar via DigiLocker'),
            ),
            const Divider(height: 32),
            const Text(
              'Verify Vehicle Registration (Vahan RC)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vehicleController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. MH12AB1234',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  onPressed: _verifyVahanRC,
                  child: const Text('Verify RC'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsUploadSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_upload, color: Colors.teal, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Manual Document Uploads',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFileSelector('Aadhaar Card (PDF / Image)', _aadhaarFileName, () => _pickMockFile('aadhaar')),
            const SizedBox(height: 12),
            _buildFileSelector('Vehicle Reg RC (PDF / Image)', _rcFileName, () => _pickMockFile('rc')),
            const SizedBox(height: 12),
            _buildFileSelector('Ambulance Permit (PDF / Image)', _permitFileName, () => _pickMockFile('permit')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submitDocuments,
                child: const Text('Submit Verification Documents', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector(String title, String? fileName, VoidCallback onPick) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                fileName ?? 'No file selected',
                style: TextStyle(color: fileName != null ? Colors.teal : Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black87,
          ),
          onPressed: onPick,
          child: const Text('Select File'),
        ),
      ],
    );
  }

  Widget _buildPendingDetailCard() {
    return const Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange, size: 48),
            SizedBox(height: 16),
            Text(
              'Documents Under Verification',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Our admins are checking your uploaded credentials and DigiLocker records. This process typically takes up to 24 hours. You will receive an update once completed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedCard() {
    return Card(
      elevation: 2,
      color: Colors.green.shade50,
      child: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'Profile Fully Verified',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green),
            ),
            SizedBox(height: 8),
            Text(
              'You are registered as a verified ambulance driver. You can toggle availability on the homepage to start accepting emergency rides.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
