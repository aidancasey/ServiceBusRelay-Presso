using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.ServiceModel.Web;
using System.Text;
using System.Threading.Tasks;
using Common;
using OnPremise.Service;

namespace OnPremise.ServiceHost
{
    class Program
    {

        private static void Main(string[] args)
        {
            try
            {
                var serviceNamespace = ConfigurationManager.AppSettings.Get("Microsoft.ServiceBus.ConnectionString");
                var servicePaths = new Dictionary<Type, string>
                                       {
                                           {typeof (PersonService), "person"},
                                            {typeof (ImageService), "image"}
                                       };
                var hosts = new BlockingCollection<WebServiceHost>();
                var helper = new ServiceHostHelper();

                Console.WriteLine("Establishing connection to Azure Service Bus..");

                Parallel.ForEach(servicePaths, (path) =>
                                                   {
                                                       var hostTuple = helper.InitServiceHost(path.Key, "https",
                                                                                              serviceNamespace,
                                                                                              path.Value);
                                                       hosts.Add(hostTuple.Item1);
                                                       Console.WriteLine("listening on " + hostTuple.Item2);
                                                   });

                Console.WriteLine("Ready !");
                Console.WriteLine();
                Console.WriteLine("Press [Enter] to exit");
                Console.ReadLine();

                Parallel.ForEach(hosts, (host) => host.Close());
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);

                Console.WriteLine();
                Console.WriteLine("Press [Enter] to exit");
                Console.ReadLine();
            }
        }
    }
}
