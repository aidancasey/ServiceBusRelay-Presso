using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Common.DataModel;

namespace Cloud.Services
{
    public class ImageService : ServiceBase 
    {

        public Stream DonwloadImage(string name)
        {
            return TryCatch(() =>
            {
                var url = string.Format(@"https://{0}/image/photo?name={1}",
                                       baseAddress, name);
                var responseData = DownloadResourceStream(url);
                return responseData;
            });
        }
    }
}
