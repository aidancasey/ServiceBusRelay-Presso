using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Data.Linq.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using AutoMapper;
using Common.DataModel;

namespace OnPremise.DataAccess
{
    public class PersonRepository
    {

        public PersonRepository()
        {
            Mapper.CreateMap<Person, PersonDto>();
            Mapper.CreateMap<Person, PersonDto>();
        }

        public Collection<PersonDto> GetAll()
        {
            var ctx = new AdventureWorks2012Entities();
            var people = (from p in ctx.People select p).Take(30).ToList();

            return Mapper.Map<List<Person>, Collection<PersonDto>>(people);


        }

        public Collection<PersonDto> SearchByFirstName(string match)
        {
            var ctx = new AdventureWorks2012Entities();
            var people = (from p in ctx.People
                          where p.FirstName.ToLower().Contains(match.ToLower())
                          select p).Take(30).ToList();

            return Mapper.Map<List<Person>, Collection<PersonDto>>(people);


        }

    }
}
