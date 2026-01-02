import '../../../preferences/heart_rate_gap_workaround.dart';
import '../../../preferences/heart_rate_limiting.dart';
import '../../../utils/constants.dart';
import '../../export_record.dart';
import '../fit_base_type.dart';
import '../fit_data.dart';
import '../fit_definition_message.dart';
import '../fit_field.dart';
import '../fit_message.dart';
import '../fit_serializable.dart';
import '../fit_utils.dart';

class FitDataRecord extends FitDefinitionMessage {
  final double altitude;
  final String heartRateGapWorkaround;
  final int heartRateUpperLimit;
  final String heartRateLimitingMethod;
  final bool outputGps;

  FitDataRecord(
    int localMessageType,
    this.altitude,
    this.heartRateGapWorkaround,
    this.heartRateUpperLimit,
    this.heartRateLimitingMethod,
    this.outputGps,
  ) : super(localMessageType, FitMessage.record) {
    fields = [
      FitField(253, FitBaseTypes.uint32Type), // Timestamp
    ];

    if (outputGps) {
      fields.addAll([
        FitField(0, FitBaseTypes.sint32Type), // PositionLat
        FitField(1, FitBaseTypes.sint32Type), // PositionLong
        FitField(2, FitBaseTypes.uint16Type), // Altitude
      ]);
    }

    fields.addAll([
      FitField(3, FitBaseTypes.uint8Type), // HeartRate (bpm)
      FitField(4, FitBaseTypes.uint8Type), // Cadence (rpm or spm?)
      FitField(5, FitBaseTypes.uint32Type), // Distance (1/100 m)
      FitField(6, FitBaseTypes.uint16Type), // Speed (1/1000 m/s)
      FitField(7, FitBaseTypes.uint16Type), // Power (Watts)
      FitField(10, FitBaseTypes.uint8Type), // Resistance (native FIT field)
      FitField(33, FitBaseTypes.uint16Type), // Calories (kCal)
      FitField(32, FitBaseTypes.sint16Type), // Vertical Speed (1/1000 m/s)
      FitField(28, FitBaseTypes.sint16Type), // Grade / Inclination (1/100 %)
    ]);
  }

  @override
  List<int> serializeData(dynamic parameter) {
    ExportRecord model = parameter;

    var data = FitData();
    data.output = [localMessageType];
    final dateTime = model.record.timeStamp ?? DateTime.now();
    data.addLong(FitSerializable.fitTimeStamp(dateTime));
    if (outputGps) {
      data.addGpsCoordinate(model.latitude);
      data.addGpsCoordinate(model.longitude);
      data.addShort(convertAltitudeForFit(altitude));
    }

    if (model.record.heartRate != null) {
      if (model.record.heartRate == 0 &&
          (heartRateGapWorkaround == dataGapWorkaroundDoNotWriteZeros ||
              heartRateLimitingMethod == heartRateLimitingWriteNothing)) {
        // #93 #113 #114
        model.record.heartRate = FitBaseTypes.uint8Type.invalidValue;
      }
    } else {
      if (heartRateGapWorkaround != dataGapWorkaroundDoNotWriteZeros &&
          heartRateLimitingMethod != heartRateLimitingWriteNothing) {
        model.record.heartRate = 0;
      } else {
        model.record.heartRate = FitBaseTypes.uint8Type.invalidValue;
      }
    }

    data.addByte(model.record.heartRate ?? 0);
    data.addByte(model.record.cadence ?? 0);
    data.addLong(((model.record.distance ?? 0.0) * 100).round());
    data.addShort(((model.record.speed ?? 0.0) * 1000).round());
    data.addShort(model.record.power?.round() ?? 0);

    // Resistance: only meaningful for certain sports.
    int resistanceByte = FitBaseTypes.uint8Type.invalidValue; // 255
    final rs = model.record.resistance;
    if (rs != null && rs > 0) {
      // clamp to valid uint8 (0..254)
      resistanceByte = rs.clamp(0, FitBaseTypes.uint8Type.maxValue);
    }
    data.addByte(resistanceByte);

    data.addShort(model.record.calories);

    data.addShort(0, signed: true);

    int inclinationShort = FitBaseTypes.sint16Type.invalidValue;
    final inc = model.record.inclination;
    if (inc != null) {
      inclinationShort = (inc * 100).round();
    }
    data.addShort(inclinationShort, signed: true);

    return data.output;
  }
}
