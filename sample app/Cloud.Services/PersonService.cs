using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Common.DataModel;

namespace Cloud.Services
{
    public class PersonService : ServiceBase 
    {

        public Collection<PersonDto> Search(string matchCriteria)
        {
            return TryCatch(() =>
            {
                var url = string.Format(@"https://{0}/person/search?firstName={1}",
                                       baseAddress, matchCriteria);
                var responseData = DownloadResource<Collection<PersonDto>>(url);
                return responseData;
            });
        }
    }
}
