using System;
using System.Collections.Generic;
using System.IO;
using System.Drawing.Imaging;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Common.ServiceContract;
using System.Drawing;
using System.ServiceModel.Web;

namespace OnPremise.Service
{
    public class ImageService :IImageService
    {
        Image img;
        public Stream GetImage(string name)
        {

            Console.WriteLine("GetImage() " + name);
            string fileName = string.Format(@"C:\Code\MTUG May 2013\images\{0}.jpg", name);

            img = Image.FromFile(fileName);

            MemoryStream stream = new MemoryStream();
            this.img.Save(stream, ImageFormat.Jpeg);

            stream.Position = 0;
            WebOperationContext.Current.OutgoingResponse.ContentType = "image/jpeg";

            return stream;
        }
    }
}
