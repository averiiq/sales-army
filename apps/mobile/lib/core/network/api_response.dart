class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int statusCode;

  const ApiResponse({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.statusCode = 200,
  });

  factory ApiResponse.success(T data, {int statusCode = 200}) {
    return ApiResponse(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error(String message, {int statusCode = 500}) {
    return ApiResponse(
      isSuccess: false,
      errorMessage: message,
      statusCode: statusCode,
    );
  }
}
