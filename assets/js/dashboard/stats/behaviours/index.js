import React, { Fragment, useState } from 'react'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'

import Funnel from './funnel'
import Conversions from './conversions'

const ACTIVE_CLASS = 'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading truncate text-left'
const DEFAULT_CLASS = 'hover:text-indigo-600 cursor-pointer truncate text-left'


function Tabs({ tab, setTab, site }) {
  return (
    <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
      <div className={classNames({ [ACTIVE_CLASS]: tab == 'conversions', [DEFAULT_CLASS]: tab !== 'conversions' })} onClick={() => setTab('conversions')}>Conversions</div>
      {FunnelTab({ tab, setTab, site })}
    </div>
  )
}

function FunnelTab({ tab, setTab, site }) {
  const funnelNames = site.funnels.map(({ name }) => name)

  return <Menu as="div" className="relative inline-block text-left">
    <div>
      <Menu.Button className="inline-flex justify-between focus:outline-none">
        <span className={funnelNames.includes(tab) ? ACTIVE_CLASS : DEFAULT_CLASS}>Funnels</span>
        <ChevronDownIcon className="-mr-1 ml-1 h-4 w-4" aria-hidden="true" />
      </Menu.Button>
    </div>

    <Transition
      as={Fragment}
      enter="transition ease-out duration-100"
      enterFrom="transform opacity-0 scale-95"
      enterTo="transform opacity-100 scale-100"
      leave="transition ease-in duration-75"
      leaveFrom="transform opacity-100 scale-100"
      leaveTo="transform opacity-0 scale-95"
    >
      <Menu.Items className="text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10">
        <div className="py-1">
          {funnelNames.map((option) => {
            return (
              <Menu.Item key={option}>
                {({ active }) => (
                  <span
                    onClick={() => setTab(option)}
                    className={classNames(
                      active ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer' : 'text-gray-700 dark:text-gray-200',
                      'block px-4 py-2 text-sm',
                      tab === option ? 'font-bold' : ''
                    )}
                  >
                    {option}
                  </span>
                )}
              </Menu.Item>
            )
          })}
        </div>
      </Menu.Items>
    </Transition>
  </Menu>
}

export default function Behaviours({ query, site }) {
  const [tab, setTab] = useState('conversions')

  const tabs = <Tabs tab={tab} setTab={setTab} site={site} />

  const selectedFunnel = site.funnels.find(funnel => funnel.name === tab)
  const funnelNames = site.funnels.map(({ name }) => name)

  return (
    <div className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825">
      {tab == 'conversions' && <Conversions tabs={tabs} query={query} site={site} />}
      {funnelNames.includes(tab) && <Funnel tabs={tabs} funnel={selectedFunnel} query={query} site={site} />}
    </div>
  )
}
