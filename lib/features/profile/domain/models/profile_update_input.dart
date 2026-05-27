class ProfileUpdateInput {
  const ProfileUpdateInput({
    this.bio,
    this.firstName,
    this.lastName,
    this.handle,
  });

  final String? bio;
  final String? firstName;
  final String? lastName;
  final String? handle;

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (handle != null) body['handle'] = handle;
    return body;
  }
}
