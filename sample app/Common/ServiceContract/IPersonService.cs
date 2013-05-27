using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.ServiceModel;
using System.ServiceModel.Web;
using System.Text;
using System.Threading.Tasks;
using Common.DataModel;

namespace Common.ServiceContract
{
    [ServiceContract(Name = "PersonCloudburstingContract", Namespace = "http://cloudburst.mtug.com/Person/Relay/")]
    public interface IPersonService
    {
        [OperationContract]
        [WebGet(ResponseFormat = WebMessageFormat.Json, UriTemplate = "/search?firstName={firstName}")]
        Collection<PersonDto> Search(string firstName);

        [OperationContract] 
        [WebGet(ResponseFormat = WebMessageFormat.Json, UriTemplate = "/all")]
         Collection<PersonDto> GetAll();
    }
}
