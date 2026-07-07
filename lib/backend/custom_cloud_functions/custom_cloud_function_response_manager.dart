class GoogleMapsProxyCloudFunctionCallResponse {
  GoogleMapsProxyCloudFunctionCallResponse({
    this.errorCode,
    this.succeeded,
    this.jsonBody,
  });
  String? errorCode;
  bool? succeeded;
  dynamic jsonBody;
}

class SyncClockInToAWSCloudFunctionCallResponse {
  SyncClockInToAWSCloudFunctionCallResponse({
    this.errorCode,
    this.succeeded,
    this.jsonBody,
  });
  String? errorCode;
  bool? succeeded;
  dynamic jsonBody;
}

class NotifyAdminOnJobPendingCloudFunctionCallResponse {
  NotifyAdminOnJobPendingCloudFunctionCallResponse({
    this.errorCode,
    this.succeeded,
    this.jsonBody,
  });
  String? errorCode;
  bool? succeeded;
  dynamic jsonBody;
}
