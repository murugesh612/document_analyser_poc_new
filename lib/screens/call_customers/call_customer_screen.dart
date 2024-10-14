import 'dart:async';
import 'dart:convert';
import 'package:document_analyser_poc_new/blocs/customer_phone_call/customer_phone_call_bloc.dart';
import 'package:document_analyser_poc_new/blocs/policy/policy_bloc.dart'
    as ranked_policy;
import 'package:document_analyser_poc_new/models/leads.dart';
import 'package:document_analyser_poc_new/screens/call_customers/widgets/generate_policies.dart';
import 'package:document_analyser_poc_new/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class CallCustomerPage extends StatefulWidget {
  final Leads lead;
  const CallCustomerPage({super.key, required this.lead});

  @override
  State<CallCustomerPage> createState() => _CallCustomerPageState();
}

class _CallCustomerPageState extends State<CallCustomerPage> {
  bool _isCalling = false;
  Timer? _callTimer;
  int _elapsedTime = 0;
  late TextEditingController _callSummaryController;

  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _callSummaryController = TextEditingController();

    socket = IO.io("ws://localhost:5000", <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.on('summary_data', (data) {
      print('websocket listener data - $data');
    });

    socket.connect();
  }

  void _getRankedPolicies(String summary) {
    context
        .read<ranked_policy.PolicyBloc>()
        .add(ranked_policy.FetchRankedPolicies(summary: summary));
  }

  void _getcallsummary() {
    context.read<CustomerPhoneCallBloc>().add(const GetCallSummary());
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callSummaryController.dispose();
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  void _toggleCall() {
    setState(() {
      _isCalling = !_isCalling;

      if (_isCalling) {
        // Emit offer event when the call starts
        _sendCallOfferEvent();

        // Start the call timer
        _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _elapsedTime++;
          });
        });
      } else {
        _callTimer?.cancel();

        setState(() {
          _elapsedTime = 0;
        });
      }
    });
  }

  void _sendCallOfferEvent() {
    Map<String, dynamic> dataToSend = {'audio_data': 'test data, working....'};
    socket.emit('offer', dataToSend);
  }

  String _formatElapsedTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(child: _buildUI()),
            )
          ],
        ),
      ),
    );
  }

  Column _buildUI() {
    final deviceType = AppHelpers.getDevice(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerCard(),
        const SizedBox(height: 16.0),
        deviceType == Devices.webpage
            ? _customerDetailsDesktop()
            : _customerDetailsMobile(),
        const SizedBox(height: 16.0),
        _buildMainContent(),
        const SizedBox(height: 16.0)
      ],
    );
  }

  Card _headerCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.lead.leadName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24.0,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _toggleCall,
              icon: Icon(_isCalling ? Icons.call_end : Icons.phone),
              label: Text(_isCalling
                  ? "End Call (${_formatElapsedTime(_elapsedTime)})"
                  : "Call Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCalling ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Card _customerDetailsDesktop() {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Customer Name:  ${widget.lead.leadName}"),
                  const SizedBox(height: 8.0),
                  Text("Email: ${widget.lead.contactInfo}"),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Phone: ${widget.lead.contactInfo}"),
                  const SizedBox(height: 8.0),
                  const Text("Address: 123 Main St, City, State"),
                ],
              ),
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Lead Source: XYZ"),
                  SizedBox(height: 8.0),
                  Text("Call History Updated: Yes"),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Edit
              },
            ),
          ],
        ),
      ),
    );
  }

  SizedBox _customerDetailsMobile() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Customer Name: ${widget.lead.leadName}"),
              const SizedBox(height: 10),
              Text("Email: ${widget.lead.contactInfo}"),
              const SizedBox(height: 10),
              const Text("Phone: 123-456-7890"),
              const SizedBox(height: 10),
              const Text("Address: 123 Main St, City, State"),
              const SizedBox(height: 10),
              const Text("Lead Source: XYZ"),
              const SizedBox(height: 10),
              const Text("Call History Updated: Yes"),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summarizeUsingAIButton(),
        BlocBuilder<CustomerPhoneCallBloc, CustomerPhoneCallState>(
          builder: (context, state) {
            if (state is LoadingState && state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else if (state is ErrorState) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Error: ${state.error.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            } else {
              if (state is CallSummaryState) {
                _callSummaryController.text = state.callSummary;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Call Summary",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: _callSummaryController,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: (state is CallSummaryState)
                          ? 'Call summary generated.'
                          : 'No summary available...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.black),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  ElevatedButton _summarizeUsingAIButton() {
    return ElevatedButton(
      onPressed: () {
        String summary = _callSummaryController.text;
        _getRankedPolicies(summary);
      },
      child: const Text("Summarize Call using AI"),
    );
  }
}
