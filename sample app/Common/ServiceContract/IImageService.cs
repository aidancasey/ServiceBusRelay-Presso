using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.ServiceModel;
using System.ServiceModel.Web;
using System.Text;

namespace Common.ServiceContract
{

   [ServiceContract(Name = "ImageCloudburstingContract", Namespace = "http://cloudburst.mtug.com/Image/Relay/")]
    public interface IImageService
    {
        [OperationContract]
        [WebGet(UriTemplate = "/photo?name={name}")]
        Stream GetImage(string name);
    }
}
