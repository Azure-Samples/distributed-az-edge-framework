namespace Distributed.Azure.IoT.Edge.Common
{
    using global::System.Text;
    using global::System.Text.Json;

    public static class JsonDocumentExtensions
    {
        public static string ToJsonString(this JsonDocument doc)
        {
            if (doc is null)
            {
                throw new ArgumentNullException(nameof(doc));
            }

            using (var stream = new MemoryStream())
            {
                using (var writer = new Utf8JsonWriter(stream))
                {
                    doc.WriteTo(writer);
                    writer.Flush();
                    return Encoding.UTF8.GetString(stream.ToArray());
                }
            }
        }
    }
}
