using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace Cloud.Services
{
    public class ServiceBase
    {

        public string baseAddress = "mtug12.servicebus.windows.net";
      
        
        protected TResource DownloadResource<TResource>(string url) where TResource : class
        {
          
            using (var serviceRequest = new WebClient())
            {
                var response = serviceRequest.DownloadString(new Uri(url));
                return JsonConvert.DeserializeObject<TResource>(response);
            }
        }

        protected Stream DownloadResourceStream(string url)
        {

            using (var serviceRequest = new WebClient())
            {
                var response = serviceRequest.DownloadData(new Uri(url));
                Stream stream = new MemoryStream(response);
                return stream;
            }
        }



        protected void TryCatch(Action action, string message = "")
        {
            try
            {
                action();
            }
            //catch (JsonReaderException)
            //{
            //    throw new OnPremiseServiceUnavailableException();
            //}
            catch (Exception exception)
            {
                //  Logger.Error(exception);
                throw (exception);
            }
        }

        protected TResult TryCatch<TResult>(Func<TResult> func, string message = "")
            where TResult : class
        {
            try
            {
                return func();
            }
            //catch (JsonReaderException)
            //{
            //    throw new OnPremiseServiceUnavailableException();
            //}
            catch (Exception exception)
            {
                //Logger.Error(exception);
                throw (exception);
                return default(TResult);
            }
        }
    }
}
