library crossdart.non_semver_version;
import 'package:pub_semver/pub_semver.dart' as ps;

class Version implements ps.Version {
  final String string;

  Version._(this.string);

  static Version parse(String string) {
    try {
      return new ps.Version.parse(string);
    } on FormatException catch (_, __) {
      return new Version._(string);
    }
  }

  String toString() {
    return string;
  }

  @override
  final int major = null;

  @override
  final int minor = null;

  @override
  final int patch = null;

  @override
  final List preRelease = null;

  @override
  final List build = null;

  @override
  bool operator <(ps.Version other) => false;

  @override
  bool operator >(ps.Version other) => false;

  @override
  bool operator <=(ps.Version other) => false;

  @override
  bool operator >=(ps.Version other) => false;

  @override
  bool get isAny => false;

  @override
  bool get isEmpty => false;

  @override
  bool get isPreRelease => false;

  @override
  ps.Version get nextMajor => this;

  @override
  ps.Version get nextMinor => this;

  @override
  ps.Version get nextPatch => this;

  @override
  ps.Version get nextBreaking => this;

  @override
  bool allows(ps.Version other) => true;

  @override
  bool allowsAll(ps.VersionConstraint other) => true;

  @override
  bool allowsAny(ps.VersionConstraint other) => true;

  @override
  ps.VersionConstraint intersect(ps.VersionConstraint other) => null;

  @override
  ps.VersionConstraint union(ps.VersionConstraint other) => null;

  @override
  int compareTo(ps.Version other) {
    return this.toString().compareTo(other.toString());
  }

  @override
  final ps.Version min = null;

  @override
  final ps.Version max = null;

  @override
  final bool includeMin = null;

  @override
  final bool includeMax = null;
}