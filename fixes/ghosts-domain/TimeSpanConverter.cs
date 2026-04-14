using System;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace Ghosts.Domain.Code.Helpers
{
    public class TimeSpanConverter : JsonConverter<TimeSpan>
    {
        /// <summary>
        /// Format: Hours:Minutes:Seconds
        /// </summary>
        private const string TimeSpanFormatString = @"hh\:mm\:ss";
        private const string TimeSpanFormatString24 = @"g";

        public override void WriteJson(JsonWriter writer, TimeSpan value, JsonSerializer serializer)
        {
            var timespanFormatted = value.ToString(TimeSpanFormatString);
            writer.WriteValue(timespanFormatted);
        }

        public override TimeSpan ReadJson(JsonReader reader, Type objectType, TimeSpan existingValue, bool hasExistingValue, JsonSerializer serializer)
        {
            try
            {
                var value = (string)reader.Value;
                if (TimeSpan.TryParseExact(value, TimeSpanFormatString, null, out var parsedTimeSpan))
                    return parsedTimeSpan;
                if (TimeSpan.TryParse(value, out var parsedTimeSpan2))
                    return parsedTimeSpan2;
                return TimeSpan.Zero;
            }
            catch
            {
                return TimeSpan.Zero;
            }
        }
    }

    public class TimeSpanArrayConverter : JsonConverter<TimeSpan[]>
    {
        public override void WriteJson(JsonWriter writer, TimeSpan[] value, JsonSerializer serializer)
        {
            if (value == null || value.Length == 0)
            {
                writer.WriteNull();
            }
            else
            {
                writer.WriteStartArray();
                foreach (var timeSpan in value)
                {
                    writer.WriteValue(timeSpan.ToString(@"hh\:mm\:ss"));
                }
                writer.WriteEndArray();
            }
        }

        public override TimeSpan[] ReadJson(JsonReader reader, Type objectType, TimeSpan[] existingValue, bool hasExistingValue, JsonSerializer serializer)
        {
            if (reader.TokenType == JsonToken.Null)
            {
                return null;
            }

            var timeSpans = new List<TimeSpan>();
            while (reader.Read())
            {
                if (reader.TokenType == JsonToken.EndArray)
                {
                    break;
                }

                if (reader.TokenType == JsonToken.String)
                {
                    if (TimeSpan.TryParseExact((string)reader.Value, @"hh\:mm\:ss", null, out var timeSpan))
                    {
                        timeSpans.Add(timeSpan);
                    }
                }
            }

            return timeSpans.ToArray();
        }
    }
}
