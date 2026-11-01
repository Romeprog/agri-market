import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/psgc_service.dart';

Future<Map<String, String>?> showPsgcLocationPicker(
  BuildContext context, {
  required Color seedColor,
  required Color bgColor,
  String initialRegion = '',
  String initialProvince = '',
  String initialCity = '',
  String initialBarangay = '',
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PsgcLocationPickerSheet(
      seedColor: seedColor,
      bgColor: bgColor,
      initialRegion: initialRegion,
      initialProvince: initialProvince,
      initialCity: initialCity,
      initialBarangay: initialBarangay,
    ),
  );
}

class PsgcLocationPickerSheet extends StatefulWidget {
  const PsgcLocationPickerSheet({super.key, 
    required this.seedColor,
    required this.bgColor,
    required this.initialRegion,
    required this.initialProvince,
    required this.initialCity,
    required this.initialBarangay,
  });

  final Color seedColor;
  final Color bgColor;
  final String initialRegion;
  final String initialProvince;
  final String initialCity;
  final String initialBarangay;

  @override
  State<PsgcLocationPickerSheet> createState() =>
      _PsgcLocationPickerSheetState();
}

class _PsgcLocationPickerSheetState extends State<PsgcLocationPickerSheet> {
  bool _bootstrapping = true;
  String? _bootstrapError;

  List<PsgcItem> _regions = [];
  List<PsgcItem> _provinces = [];
  List<PsgcItem> _cities = [];
  List<PsgcItem> _barangays = [];

  PsgcItem? _selectedRegion;
  PsgcItem? _selectedProvince;
  PsgcItem? _selectedCity;
  PsgcItem? _selectedBarangay;

  bool _loadingProvinces = false;
  bool _loadingCities = false;
  bool _loadingBarangays = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  PsgcItem? _findByName(List<PsgcItem> items, String name) {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final item in items) {
      if (item.name.trim().toLowerCase() == needle) return item;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _bootstrapError = null;
    });
    try {
      final regions = await PsgcService.fetchRegions();
      if (!mounted) return;
      setState(() => _regions = regions);

      final region = _findByName(regions, widget.initialRegion);
      if (region == null) return;
      setState(() => _selectedRegion = region);

      final provinces = await PsgcService.fetchProvinces(region.code);
      if (!mounted) return;
      setState(() => _provinces = provinces);

      final province = _findByName(provinces, widget.initialProvince);
      if (province == null) return;
      setState(() => _selectedProvince = province);

      final cities = await PsgcService.fetchCitiesMunicipalities(province.code);
      if (!mounted) return;
      setState(() => _cities = cities);

      final city = _findByName(cities, widget.initialCity);
      if (city == null) return;
      setState(() => _selectedCity = city);

      final barangays = await PsgcService.fetchBarangays(city.code);
      if (!mounted) return;
      setState(() => _barangays = barangays);

      final barangay = _findByName(barangays, widget.initialBarangay);
      if (barangay != null) {
        setState(() => _selectedBarangay = barangay);
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _bootstrapError =
            "Couldn't load locations. Check your connection and try again.",
      );
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  Future<void> _onSelectRegion() async {
    final region = await _showPicker('Select Region', _regions);
    if (region == null || region.code == _selectedRegion?.code) return;

    setState(() {
      _selectedRegion = region;
      _selectedProvince = null;
      _selectedCity = null;
      _selectedBarangay = null;
      _provinces = [];
      _cities = [];
      _barangays = [];
      _loadingProvinces = true;
    });
    try {
      final provinces = await PsgcService.fetchProvinces(region.code);
      if (!mounted) return;
      setState(() => _provinces = provinces);
    } catch (_) {
      if (mounted) _showLoadError();
    } finally {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _onSelectProvince() async {
    if (_selectedRegion == null) return;
    final province = await _showPicker('Select Province', _provinces);
    if (province == null || province.code == _selectedProvince?.code) return;

    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _selectedBarangay = null;
      _cities = [];
      _barangays = [];
      _loadingCities = true;
    });
    try {
      final cities = await PsgcService.fetchCitiesMunicipalities(province.code);
      if (!mounted) return;
      setState(() => _cities = cities);
    } catch (_) {
      if (mounted) _showLoadError();
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _onSelectCity() async {
    if (_selectedProvince == null) return;
    final city = await _showPicker('Select City / Municipality', _cities);
    if (city == null || city.code == _selectedCity?.code) return;

    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      _barangays = [];
      _loadingBarangays = true;
    });
    try {
      final barangays = await PsgcService.fetchBarangays(city.code);
      if (!mounted) return;
      setState(() => _barangays = barangays);
    } catch (_) {
      if (mounted) _showLoadError();
    } finally {
      if (mounted) setState(() => _loadingBarangays = false);
    }
  }

  Future<void> _onSelectBarangay() async {
    if (_selectedCity == null) return;
    final barangay = await _showPicker('Select Barangay', _barangays);
    if (barangay == null) return;
    setState(() => _selectedBarangay = barangay);
  }

  void _showLoadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Couldn't load that list. Please try again.")),
    );
  }

  Future<PsgcItem?> _showPicker(String title, List<PsgcItem> items) {
    return showModalBottomSheet<PsgcItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PsgcPickerSheet(
        title: title,
        items: items,
        seedColor: widget.seedColor,
        bgColor: widget.bgColor,
      ),
    );
  }

  bool get _canConfirm =>
      _selectedRegion != null &&
      _selectedProvince != null &&
      _selectedCity != null &&
      _selectedBarangay != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'Location',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.seedColor,
              ),
            ),
            SizedBox(height: 16),
            if (_bootstrapping)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: widget.seedColor),
                ),
              )
            else if (_bootstrapError != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _bootstrapError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.black54),
                ),
              ),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _bootstrap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.seedColor,
                    side: BorderSide(color: widget.seedColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else ...[
              _locationField(
                label: 'Region',
                value: _selectedRegion?.name,
                enabled: _regions.isNotEmpty,
                loading: false,
                onTap: _onSelectRegion,
              ),
              SizedBox(height: 12),
              _locationField(
                label: 'Province',
                value: _selectedProvince?.name,
                enabled: _selectedRegion != null,
                loading: _loadingProvinces,
                onTap: _onSelectProvince,
              ),
              SizedBox(height: 12),
              _locationField(
                label: 'City / Municipality',
                value: _selectedCity?.name,
                enabled: _selectedProvince != null,
                loading: _loadingCities,
                onTap: _onSelectCity,
              ),
              SizedBox(height: 12),
              _locationField(
                label: 'Barangay',
                value: _selectedBarangay?.name,
                enabled: _selectedCity != null,
                loading: _loadingBarangays,
                onTap: _onSelectBarangay,
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _canConfirm
                      ? () => Navigator.pop(context, {
                          'region': _selectedRegion!.name,
                          'province': _selectedProvince!.name,
                          'city': _selectedCity!.name,
                          'barangay': _selectedBarangay!.name,
                        })
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.seedColor,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationField({
    required String label,
    required String? value,
    required bool enabled,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled && !loading ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: widget.seedColor.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value ?? 'Select $label',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: value != null ? Colors.black87 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.seedColor,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? widget.seedColor : Colors.black26,
              ),
          ],
        ),
      ),
    );
  }
}

class _PsgcPickerSheet extends StatefulWidget {
  const _PsgcPickerSheet({
    required this.title,
    required this.items,
    required this.seedColor,
    required this.bgColor,
  });

  final String title;
  final List<PsgcItem> items;
  final Color seedColor;
  final Color bgColor;

  @override
  State<_PsgcPickerSheet> createState() => _PsgcPickerSheetState();
}

class _PsgcPickerSheetState extends State<_PsgcPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
              .where((i) => i.name.toLowerCase().contains(_query))
              .toList();

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
      child: Container(
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              widget.title,
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.seedColor,
              ),
            ),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: GoogleFonts.inter(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: widget.items.isEmpty
                  ? Center(
                      child: Text(
                        'No options available.',
                        style: GoogleFonts.inter(color: Colors.black54),
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matches found.',
                        style: GoogleFonts.inter(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.black12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          title: Text(
                            item.name,
                            style: GoogleFonts.inter(fontSize: 14.5),
                          ),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}