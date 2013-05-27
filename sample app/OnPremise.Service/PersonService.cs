using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Common.ServiceContract;
using System.ServiceModel;
using OnPremise.DataAccess;

namespace OnPremise.Service
{

    [ServiceBehavior(Name = "PersonService", Namespace = "http://cloudburst.mtug.com/PersonService/Relay/")]
    public class PersonService : IPersonService
    {
        #region IPersonService Members

        public System.Collections.ObjectModel.Collection<Common.DataModel.PersonDto> Search(string firstName)
        {
            Console.WriteLine("Search() " + firstName);

            PersonRepository dal = new PersonRepository();
            return dal.SearchByFirstName(firstName);
        }

        public System.Collections.ObjectModel.Collection<Common.DataModel.PersonDto> GetAll()
        {
            Console.WriteLine("GetAll() ");

            PersonRepository dal = new PersonRepository();
            return dal.GetAll();
        }

        #endregion
    }
}
