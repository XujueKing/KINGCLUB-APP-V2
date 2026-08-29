param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not ('ConnectedLightBackground' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class ConnectedLightBackground
{
    public static void Remove(string path)
    {
        Bitmap bitmap;
        using (var source = new Bitmap(path))
        {
            bitmap = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
            using (var graphics = Graphics.FromImage(bitmap))
                graphics.DrawImageUnscaled(source, 0, 0);
        }

        using (bitmap)
        {
            var rectangle = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
            var data = bitmap.LockBits(rectangle, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            try
            {
                var bytes = new byte[Math.Abs(data.Stride) * bitmap.Height];
                Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
                var visited = new bool[bitmap.Width * bitmap.Height];
                var queue = new Queue<int>();

                Action<int, int> enqueue = (x, y) =>
                {
                    var index = y * bitmap.Width + x;
                    if (visited[index] || !IsBackground(bytes, data.Stride, x, y)) return;
                    visited[index] = true;
                    queue.Enqueue(index);
                };

                for (var x = 0; x < bitmap.Width; x++)
                {
                    enqueue(x, 0);
                    enqueue(x, bitmap.Height - 1);
                }
                for (var y = 1; y < bitmap.Height - 1; y++)
                {
                    enqueue(0, y);
                    enqueue(bitmap.Width - 1, y);
                }

                while (queue.Count > 0)
                {
                    var index = queue.Dequeue();
                    var x = index % bitmap.Width;
                    var y = index / bitmap.Width;
                    bytes[y * data.Stride + x * 4 + 3] = 0;
                    if (x > 0) enqueue(x - 1, y);
                    if (x + 1 < bitmap.Width) enqueue(x + 1, y);
                    if (y > 0) enqueue(x, y - 1);
                    if (y + 1 < bitmap.Height) enqueue(x, y + 1);
                }

                Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
            }
            finally
            {
                bitmap.UnlockBits(data);
            }

            var temporary = path + ".transparent.png";
            bitmap.Save(temporary, ImageFormat.Png);
            File.Copy(temporary, path, true);
            File.Delete(temporary);
        }
    }

    private static bool IsBackground(byte[] bytes, int stride, int x, int y)
    {
        var offset = y * stride + x * 4;
        var blue = bytes[offset];
        var green = bytes[offset + 1];
        var red = bytes[offset + 2];
        var minimum = Math.Min(red, Math.Min(green, blue));
        var maximum = Math.Max(red, Math.Max(green, blue));
        return minimum >= 225 && maximum - minimum <= 5;
    }
}
'@
}

foreach ($item in $Path) {
    $resolved = (Resolve-Path -LiteralPath $item).Path
    [ConnectedLightBackground]::Remove($resolved)
}
