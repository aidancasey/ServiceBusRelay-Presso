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

        public string baseAddress = "mtug-1.servicebus.windows.net";
        public string sharedSecret = "vGNF+mSXrT5Wc9g946vHm5KNK/s8hsIrJqM0hnI+XtM=";

        protected string PostJson(string url, string data)
        {
            var bytes = Encoding.Default.GetBytes(data);
            using (var client = new WebClient())
            {
                client.Headers.Add("Content-Type", "application/json");
                var response = client.UploadData(url, "POST", bytes);
                return Encoding.Default.GetString(response);
            }
        }

        public string GetAuthorizationToken(string serviceNamespace, string issuerName, string issuerPassword)
        {
            var acsEndpoint = string.Format("https://{0}-sb.accesscontrol.windows.net/WRAPv0.9", serviceNamespace);
            var relyingPartyAddress = string.Format("http://{0}.servicebus.windows.net", serviceNamespace);
            var postData = new NameValueCollection
                               {
                                   {"wrap_scope", relyingPartyAddress},
                                   {"wrap_name", issuerName},
                                   {"wrap_password", issuerPassword},
                               };
            var webClient = new WebClient();
            var responseBuffer = webClient.UploadValues(acsEndpoint, "POST", postData);
            var response = Encoding.UTF8.GetString(responseBuffer);
            var encodedtoken = response.Split('&')
                                       .Single(value => value.StartsWith("wrap_access_token="))
                                       .Split('=')[1];
            var token = System.Web.HttpUtility.UrlDecode(encodedtoken);
            return token;
        }


        protected TResource DownloadResource<TResource>(string url) where TResource : class
        {
          
            using (var serviceRequest = new WebClient())
            {
                var serviceName = baseAddress.Replace(".servicebus.windows.net", "");
                var token = GetAuthorizationToken(serviceName, "owner", sharedSecret);
                serviceRequest.Headers["Authorization"] = string.Format("WRAP access_token=\"{0}\"", token);

                var response = serviceRequest.DownloadString(new Uri(url));
                return JsonConvert.DeserializeObject<TResource>(response);
            }
        }

        protected Stream DownloadResourceStream(string url)
        {

            using (var serviceRequest = new WebClient())
            {
                var serviceName = baseAddress.Replace(".servicebus.windows.net", "");
                var token = GetAuthorizationToken(serviceName, "owner", sharedSecret);
                serviceRequest.Headers["Authorization"] = string.Format("WRAP access_token=\"{0}\"", token);

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
