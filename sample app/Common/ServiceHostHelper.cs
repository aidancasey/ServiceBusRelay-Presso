using System;
using System.Collections.Generic;
using System.Linq;
using System.ServiceModel.Web;
using System.Text;
using System.Threading.Tasks;
using Microsoft.ServiceBus;

namespace Common
{
    public class ServiceHostHelper
    {
        public Tuple<WebServiceHost, Uri> InitServiceHost(Type hostType, string serviceSchema,
                                         string serviceNamespace, string servicePath)
        {
            var address = ServiceBusEnvironment.CreateServiceUri(serviceSchema, serviceNamespace, servicePath);
            var host = new WebServiceHost(hostType, address);
            host.AddDefaultEndpoints();
            host.Open();
    
            return Tuple.Create(host, address);
        }

    }
}
